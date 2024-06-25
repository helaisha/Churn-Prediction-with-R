### Customer Churn Analysis and Modeling

This repository contains scripts and code for analyzing customer churn using various machine learning models. Below is an overview of the files and directories:

---

#### Libraries Used:
- `caret`
- `dplyr`
- `readr`
- `skimr`
- `ggplot2`
- `reshape2`
- `glmnet`
- `e1071`
- `randomForest`
- `pROC`

#### Data
The dataset used for analysis is `Customer Churn.csv`. It includes various customer attributes and the target variable `Churn`.

#### Data Preprocessing:
- **Handling Missing Values**: Imputed missing values in `Charge_Amount` column using mode.
- **Encoding Categorical Variables**: Ensured proper encoding of categorical variables.

#### Exploratory Data Analysis:
- **Summary Statistics**: Utilized `summary()` and `skim()` to understand data distributions and summary statistics.
- **Visualization**: Generated plots to visualize churn distribution and categorical variable distributions.

#### Model Building:
- **Log Normalization**: Addressed skewness in numerical variables using log transformation.
- **Principal Component Analysis (PCA)**: Explored PCA as a technique to handle multicollinearity.

#### Model Evaluation:
- **Logistic Regression, SVM, Random Forest**: Trained and evaluated models both with and without PCA to compare performance metrics (Accuracy, Precision, Recall, ROC AUC).

#### Results:
- Compared model performances post Log Normalization and PCA.
- Concluded on the effectiveness of each technique in improving model stability and performance metrics.

---

### Conclusion
This repository provides a comprehensive analysis of customer churn using machine learning techniques. Both Log Normalization and PCA were explored to handle data challenges, resulting in comparable model performance. For detailed insights, refer to the code and analysis results provided.

For further inquiries, please contact [Your Contact Information].

---

Feel free to customize the contact information and additional details as per your preference and the intended audience for your README file.