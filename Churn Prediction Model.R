library(caret)
library(dplyr)
library(readr)
library(skimr)
library(ggplot2)
library(reshape2)
library(glmnet)
library(e1071)  # For SVM
library(randomForest)
library(pROC)

# read in data and encoding the categorical variable correctly
data<- read_csv("Customer Churn.csv", 
    col_types = cols(Complains = col_factor(levels = c("0",  "1")), 
    `Charge  Amount` = col_factor(levels = c("0", "1", "2", "3", "4", "5", "6", "7", "8", "9")), 
                     `Age Group` = col_factor(levels = c("1", "2", "3", "4", "5")), 
                     `Tariff Plan` = col_factor(levels = c("1", "2")), 
                     Status = col_factor(levels = c("1", "2")), 
                     Churn = col_factor(levels = c("0", "1"))))


# Rename columns with spaces
colnames(data) <- gsub("\\s+", "_", colnames(data))

head(data)
# Checking to see if there are missing data?
sum(is.na(data))
colSums(is.na(data))

# the only column with missing data is Charge_Amount and we can replace the missing data with the mode
# the code below handles the missing data

missing_values <- sum(is.na(data$Charge_Amount))

if (missing_values > 0) {
  # Defining a custom mode function to handle missing data
  get_mode <- function(x) {
    ux <- unique(x)
    ux[which.max(tabulate(match(x, ux)))]
  }
  
  # Calculate the mode of Charge_Amount
  mode_charge_amount <- as.character(get_mode(data$Charge_Amount))
  # Impute missing values with the mode
  data$Charge_Amount[is.na(data$Charge_Amount)] <- mode_charge_amount
  # Convert Charge_Amount to a factor with specified levels
  data$Charge_Amount <- factor(data$Charge_Amount, levels = c("0", "1", "2", "3", "4", "5", "6", "7", "8", "9"))
}

# Verify that missing values are handled and
colSums(is.na(data))

#get summary statistics of datasets (note the range and skewness)
summary(data)
# using  skimr() - to  expands on summary() by providing larger set of statistics
skim(data)
#notice the skewness of the variables above

# Explore the distribution of the target variable (Churn)
summary(data$Churn)
# the ratio of rows of binary class 0 and 1 is 5.365: 1 

# Visualize distribution of churn
ggplot(data, aes(x = factor(Churn))) +
  geom_bar() +
  geom_text(stat = 'count', aes(label = ..count..), vjust = -0.5) +  # Display counts on the bars
  labs(title = "Churn Distribution", x = "Churn", y = "Count") +
  scale_x_discrete(labels = c("Non-Churn", "Churn"))

# Visualize distribution of categorical variables
# getting the categorical variables
categorical_vars <- c("Complains", "Charge_Amount", "Age_Group", "Tariff_Plan", "Status")
# Reshape data for ggplot2
data_long <- tidyr::gather(data, key = "Variable", value = "Value", all_of(categorical_vars))

# Bar plots for categorical variables using facet_wrap
ggplot(data_long, aes(x = factor(Value))) +
  geom_bar() +
  facet_wrap(~Variable, scales = "free_x", ncol = 2) +
  labs(title = "Distribution of Categorical Variables")

# Visualize the distribution of numerical features
head(data)
numeric_vars <- c("Call_Failure", "Subscription_Length", "Seconds_of_Use", "Frequency_of_use",
  "Frequency_of_SMS","Distinct_Called_Numbers", "Age", "Customer_Value")

# Creating a correlation matrix to see correlated values
correlation_matrix <- cor(data[numeric_vars])
print(correlation_matrix)
# Convert correlation matrix to a data frame for plotting
correlation_df <- melt(correlation_matrix)

# Plot the heatmap with correlation values using ggplot
ggplot(data = correlation_df, aes(x = Var1, y = Var2, fill = value)) +
  geom_tile(color = "white") +
  geom_text(aes(x = Var1, y = Var2, label = round(value, 2)), vjust = 1) +  # Include correlation values
  scale_fill_gradient2(low = "gold", high = "red", mid = "white", midpoint = 0, limit = c(-1, 1), space = "Lab", name = "Correlation") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, vjust = 1, hjust = 1) ) +
  ggtitle("Correlation Heatmap for Numerical data")  # Add title

# Boxplots for numerical variables
par(mfrow = c(2, 4))
for (var in numeric_vars) {
  boxplot(data[[var]], main = var)
}

# Add a title to the entire set of boxplots
main_title <- "Boxplots for Numerical Variables"
mtext(main_title, outer = TRUE, cex = 1.1, font = 1, line = -1)

# Skewness and multicollinearity
# we notice a lot the variables are highly skewed from the boxplot also a few of the columns are highly correlated.
# this affects model performance by making it hard for models to learn, and model gets confused and its predictions become unstable.

## there are two methods to handle skewness and multicollinearity. Log normalization and Principal Component Analysis (PCA) are both techniques 
##For this code base  we will apply  both techniques to handle skewness and multicollinearity and see the performance in models.



#  Log normalization technique :

# Checking for skewness of each variable and transforming them using a log transformation
#The block of code below code uses the skewness function from the e1071 package to check the skewness of 
#each numerical variable. If the skewness is above a certain 
#threshold (in this example, 1), it applies a log transformation 
#to the variable


print("before normalisation")
print(colnames(data))

data_numerical <- data[, numeric_vars]
skewness_before <- sapply(data_numerical, skewness)
print("Skewness before transformation:")
print(skewness_before)

# Apply transformations to correct skewness
for (var in numeric_vars) {
  if (skewness_before[var] > 1) {  # Check if skewness is above a threshold (adjust as needed)
    # Log transformation
    data_numerical[[var]] <- log1p(data_numerical[[var]])
    
  }
}

# Check skewness after transformation
skewness_after <- sapply(data_numerical, skewness)
print("Skewness after transformation:")
print(skewness_after)

# Merge with categorical variables
df_merged <- cbind(data[, setdiff(names(data), numeric_vars)], data_numerical)

# Model building after Log normalization...

#Split the data into training and testing sets
train_index <- createDataPartition(df_merged$Churn, p = 0.7, list = FALSE)
train_data <- df_merged[train_index, ]
test_data <- df_merged[-train_index, ]

# Convert Churn to factor
train_data$Churn <- as.factor(train_data$Churn)
test_data$Churn <- as.factor(test_data$Churn)

# Train a logistic regression model
log_reg_model <- glm(Churn ~ ., data = train_data, family = "binomial")
log_reg_predictions <- predict(log_reg_model, newdata = test_data, type = "response")
log_reg_predicted_classes <- ifelse(log_reg_predictions > 0.5, 1, 0)
log_reg_predicted_classes <- factor(log_reg_predicted_classes, levels = levels(test_data$Churn))

# Extract coefficients from the logistic regression model
#coefficients_log_reg <- coef(log_reg_model)

# Display the coefficients
#print("Coefficients for Logistic Regression Model:")
#print(coefficients_log_reg)

summary(log_reg_model)

summary(log_reg_model)$coeff

# Train an SVM model
svm_model <- svm(Churn ~ ., data = train_data)
svm_predictions <- predict(svm_model, newdata = test_data)
svm_predictions <- factor(svm_predictions, levels = levels(test_data$Churn))

# Train a Random Forest model
rf_model <- randomForest(Churn ~ ., data = train_data)
rf_predictions <- predict(rf_model, newdata = test_data)
rf_predictions <- factor(rf_predictions, levels = levels(test_data$Churn))

# Create a data frame to store results
model_results <- data.frame(
  Model = character(0),
  Accuracy = numeric(0),
  Precision = numeric(0),
  Recall = numeric(0),
  ROC_AUC = numeric(0)
)

# Evaluate and populate the data frame for
evaluate_model <- function(predictions, model_name) {
  cm <- confusionMatrix(predictions, test_data$Churn)
  
  # ROC-AUC
  roc_curve <- roc(test_data$Churn, as.numeric(predictions))
  roc_auc <- auc(roc_curve)
  
  # Plot ROC-AUC curve
  plot(roc_curve, main = paste(model_name, "ROC Curve after Log normalization"), col = "blue", lwd = 2)
  
  result <- data.frame(
    Model = model_name,
    Accuracy = cm$overall["Accuracy"],
    Precision = cm$byClass["Precision"],
    Recall = cm$byClass["Recall"],
    ROC_AUC = roc_auc
  )
  
  return(result)
}


# Evaluate logistic regression model
log_reg_results <- evaluate_model(log_reg_predicted_classes, "Logistic Regression")
model_results <- rbind(model_results, log_reg_results)

# Evaluate SVM model
svm_results <- evaluate_model(svm_predictions, "SVM")
model_results <- rbind(model_results, svm_results)

# Evaluate Random Forest model
rf_results <- evaluate_model(rf_predictions, "Random Forest")
model_results <- rbind(model_results, rf_results)

# Display the results data frame
print(model_results)




#  Principal Component Analysis Technique :

# Performing PCA on numerical variables
pca_result <- prcomp(data_numerical, scale = TRUE)

# Ploting the cumulative proportion of variance explained by principal components
plot(cumsum(pca_result$sdev^2 / sum(pca_result$sdev^2)), xlab = "Number of Principal Components", ylab = "Cumulative Proportion of Variance Explained", type = "b")

# Choosing the number of principal components based on the plot (5)
n_components <- 5  

# Extract the selected principal components
pca_data <- as.data.frame(predict(pca_result, newdata = data_numerical)[, 1:n_components])

# Merge PCA components with categorical variables
df_pca <- cbind(data[, setdiff(names(data), numeric_vars)], pca_data)

# Split the data into training and testing sets
train_index_pca <- createDataPartition(df_pca$Churn, p = 0.7, list = FALSE)
train_data_pca <- df_pca[train_index_pca, ]
test_data_pca <- df_pca[-train_index_pca, ]

# Convert Churn to factor
train_data_pca$Churn <- as.factor(train_data_pca$Churn)
test_data_pca$Churn <- as.factor(test_data_pca$Churn)

# Train a logistic regression model with PCA components
log_reg_model_pca <- glm(Churn ~ ., data = train_data_pca, family = "binomial")
log_reg_predictions_pca <- predict(log_reg_model_pca, newdata = test_data_pca, type = "response")
log_reg_predicted_classes_pca <- ifelse(log_reg_predictions_pca > 0.5, 1, 0)
log_reg_predicted_classes_pca <- factor(log_reg_predicted_classes_pca, levels = levels(test_data_pca$Churn))



# Train an SVM model with PCA components
svm_model_pca <- svm(Churn ~ ., data = train_data_pca)
svm_predictions_pca <- predict(svm_model_pca, newdata = test_data_pca)
svm_predictions_pca <- factor(svm_predictions_pca, levels = levels(test_data_pca$Churn))

# Train a Random Forest model with PCA components
rf_model_pca <- randomForest(Churn ~ ., data = train_data_pca)
rf_predictions_pca <- predict(rf_model_pca, newdata = test_data_pca)
rf_predictions_pca <- factor(rf_predictions_pca, levels = levels(test_data_pca$Churn))

# Create a data frame to store results with PCA
model_results_pca <- data.frame(
  Model = character(0),
  Accuracy = numeric(0),
  Precision = numeric(0),
  Recall = numeric(0),
  ROC_AUC = numeric(0)
)

# Evaluate and populate the data frame with PCA
evaluate_model_pca <- function(predictions, model_name) {
  cm_pca <- confusionMatrix(predictions, test_data_pca$Churn)
  
  # ROC-AUC
  roc_curve_pca <- roc(test_data_pca$Churn, as.numeric(predictions))
  roc_auc_pca <- auc(roc_curve_pca)
  
  # Plot ROC-AUC curve with PCA
  roc_curve_pca <- roc(test_data_pca$Churn, as.numeric(predictions))
  plot(roc_curve_pca, main = paste(model_name, "ROC Curve with PCA"), col = "blue", lwd = 2)
  
  result_pca <- data.frame(
    Model = model_name,
    Accuracy = cm_pca$overall["Accuracy"],
    Precision = cm_pca$byClass["Precision"],
    Recall = cm_pca$byClass["Recall"],
    ROC_AUC = roc_auc_pca
  )
  
  return(result_pca)
}

# Evaluate logistic regression model with PCA
log_reg_results_pca <- evaluate_model_pca(log_reg_predicted_classes_pca, "Logistic Regression with PCA")
model_results_pca <- rbind(model_results_pca, log_reg_results_pca)

# Evaluate SVM model with PCA
svm_results_pca <- evaluate_model_pca(svm_predictions_pca, "SVM with PCA")
model_results_pca <- rbind(model_results_pca, svm_results_pca)

# Evaluate Random Forest model with PCA
rf_results_pca <- evaluate_model_pca(rf_predictions_pca, "Random Forest with PCA")
model_results_pca <- rbind(model_results_pca, rf_results_pca)

# Display the results data frame with PCA
print(model_results_pca)


# Display the results data for models after Log normalization
print("Results data for models after Log normalization")
print(model_results)

print("Results data for models after PCA")
print(model_results_pca)

## conclusion
# there isn't major difference between model performance after Log Normalization or PCA in this particular context.

#PCA is better at addressing multicollinearity and skewness
#although  have an impact on the variance and distribution of the data,
# which may indirectly affect multicollinearity, it's strength us mostly on
# addressing challenges related to the scale and distribution of data.

