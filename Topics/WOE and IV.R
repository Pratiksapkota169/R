## the data is from an historical marketing campaign from the insurance industry and is automatically 
## downloaded when you install the "information" package. 
## The data is sotred in two .RND files, one for the trining dataset and one for the 
## validation dataset. Each file has 68 predictive variables and 10k records.
##
## The datasets contain two key indicators:
## purchase: this variable equals 1 if the client accepted the offer
## treatment: this variable equals 1 if the client was in the test group
##
## Key functions
## create_infotables() creates WOE tables and IVs for all variables in the input dataframe.
## plot_infotables() plots the WOE patterns
##
## External Cross Validation
## The information package supports external cross validation to check that the WOE and NWOE vectors are stable



## Example for a Traditional Bianry Classification Problem
## Ranking All Variables Using Adjusted IV
library(Information)
library(gridExtra)
data(train, package = "Information")
data(valid, package = "Information")
## Exclude the control group
train <- subset(train, TREATMENT == 1)
valid <- subset(valid, TREATMENT == 1)
## Ranking variables using pernalized IV
IV <- create_infotables(data = train, valid = valid, y = "PURCHASE")
grid.table(head(IV$Summary), row=NULL)

## Analyzing WOE Patterns
## The IV$Tables object returned by Information is simply a list of dataframes that contains
## the WOE tables for all variables in the input dataset
## Note that hte penalty and IV columns are cumulative
IV$Tables
grid.table(IV$Tables$N_OPEN_REV_ACTS, rows=NULL)
## The table shows that the odds of PURCHASE = 1 increase as this variable increases,
## although the relationship is not linear
plot(1:7,c(-2.0465968,-0.5900120,0.2033085,0.4419768,0.6148243,0.8815772,0.9883818))

## Note that the Information package attempts to create evenly-sized bins in terms of the number
## of subjects in each group. However, this is not always possible due to ties in the data,
## as with N_OPEN_REV_ACTS which has ties at 0

## If the variable is categorical, its distinct categories will show up as rows in the WOE table
## If the variable has missing values, the WOE table will contain a separate NA row which can be
## used to gauge the impact of missing values
## Thus, the framework seamlessly handles missing values and categorical variables without 
## any dummy-coding or imputation

## Plotting WOE Patterns
plot_infotables(IV, "N_OPEN_REV_ACTS")
## For better visualization we can do a multiplot to compare WOE patterns
MultiPlot(IV, IV$Summary$Variable[1:9])

## Omitting Cross Validation
## To run IVs without external cross validation, simply oit the validation dataset

## Changing the Number of Bins
## the default number of bins is 10 but we can choose a different number if we desire
## more granularity. Note that the IV formula is fairly invariant to the number of bins
IV <- create_infotables(data = train, valid = valid, y = "PURCHASE", bins = 20)
grid.table(IV$Tables$N_OPEN_REV_ACTS,
           rows = NULL)

## Uplift Example
## For an uplift model we have to include both the test group and the control group 
## in our dataset
data(train, package = "Information")
data(valid, package = "Information")
## When calling the create_infotables() function, all we have to do is specify the variable that 
## identifies the test and control groups
NIV <- create_infotables(data = train, valid = valid, y = "PURCHASE", trt = "TREATMENT")
grid.table(head(NIV$Summary),
           rows=NULL)
## Note that we cannot compare the scales of NIV and IV. Moreover, there is no rule-of-thumb
## cutoff for the NIV. Hence, we have to use it solely as a ranking statistic and make a judgement call

## Interestingly, N_OPEN_REV_ACTS is also the most predictive variable 
## from an uplift perspective. However, the NWOE pattern is quite different 
## from the WOE pattern and suggests a u-shaped pattern. 
## This illustrates how the story can be very different when modeling the 
## incremental effect as opposed to simply building a model to estimate the 
## chance of Y=1 following a treatment.



## Combining IV Analysis with Variable Clustering
## Variable clustering divides a set of numeric variables into mutually exclusive clusters
## The algorithm attempts to generate clusters such that 
##      the correlation between variables assigned to the same cluster are maximized
##      the correlation between variables in different clusters are minimized

## Using this alrogithm we can replace a large set of variables by a single member of each cluster,
## often with little loss of information. The question is which member to choose from a given cluster
## One option is to choose the variable that has the highest multiple correlation with the variables within
## its cluster, and the lowest correlation with variables outside the cluster
## A more meaningful choice for a predictive modeling is to choose the variable that has the highest
## information value

require(ClustOfVar)
require(reshape2)
require(plyr)

data(train, package = "Information")
data(valid, package = "Information")
train <- subset(train, TREATMENT == 1)
valid <- subset(valid, TREATMENT == 1)

tree <- hclustvar(train[,!(names(train) %in% c("PURCHASE","TREATMENT"))])
nvars <- length(tree[tree$height < 0.7])
part_init <- cutreevar(tree,nvars)$cluster
kmeans <- kmeansvar(X.quanti=train[,!(names(train) %in% c("PURCHASE", "TREATMENT"))],init=part_init)
clusters <- cbind.data.frame(melt(kmeans$cluster), row.names(melt(kmeans$cluster)))
names(clusters) <- c("Cluster", "Variable")
clusters <- join(clusters, IV$Summary, by="Variable", type="left")
clusters <- clusters[order(clusters$Cluster),]
clusters$Rank <- ave(-clusters$AdjIV, clusters$Cluster, FUN=rank)
selected_members <- subset(clusters, Rank==1)

