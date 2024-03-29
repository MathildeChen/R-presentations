# Friday 14th June 2019
# RLadies Paris - Survival Analysis
# ----------
# Packages

# Data manipulation
library(tidyverse)
# Graphical tools
library(ggplot2)
library(viridis)

# Survival package installation 
#install.packages("survival")
library(survival)

# Survival curves visualization
#install.packages("survminer")
library(survminer)

# ----------
# Data
lung <- lung %>% 
  mutate(sex.r = recode(sex, "1" = "Male", "2" = "Female"),
         treatment = rep(c("doliprane", "aspirine"), nrow(lung)/2))

# Data overview
head(lung)

# Which type of censoring?
unique(lung$status)
# (2 = death)

# Proportion of censored data
table(lung$status, useNA = "ifany")/nrow(lung)*100

# ----------
# Time-to-event data structuration

# Right censored data
Surv(time = lung$time, event = lung$status, type = "right") 

# another possible syntax 
with(lung, Surv(time = time, event = status))  

# Distribution of events' time
# It helps to notice when censoring is more common. 
surv <- Surv(time = lung$time, event = lung$status) 

ggsurvevents(surv, 
             palette = c("grey50", "grey90"), 
             ggtheme = theme_light(), 
             # censored event on the top of the graph
             censored.on.top = T)

# -----------
# Non-parametric fitting (Kaplan Meier)

# Fitting 
np <- survfit(Surv(time, status) ~ 1, data = lung)
np            # a summary of the survival in the population
summary(np)   # a complete summary of the survival

# Survival curve can be plotted very easily
plot(np, 
     xlab = "Time",
     ylab = "S(t)",
     col = "red",
     conf.int = TRUE)

# Survival curve (ggsurvplot() function from ggsurvminer package)
ggsurvplot(np, 
           # indicating the median survival time
           surv.median.line = "hv", 
           # add a risk table
           risk.table = TRUE,
           legend = "none",
           ggtheme = theme_light())  

# Significant difference between females and males?
np.sex <- survfit(Surv(time, status) ~ sex.r, data = lung)
summary(np.sex) # a complete summary of the survival for both gender

# Survival curve by sex
ggsurvplot(np.sex, 
           surv.median.line = "hv", 
           # add a risk table
           risk.table = TRUE,
           # print confidence interval
           conf.int = T,
           # put the legend on the right
           legend = "right",
           # change the legend title
           legend.title = "Sex",
           ggtheme = theme_light())

# Survival curve by treatment
ggsurvplot_facet(np.sex, 
                 data = lung,
                 # variable for facetting
                 facet.by = "treatment",
                 ggtheme = theme_light())

# -----------
# Semi-parametric fitting (Cox)
sp <- coxph(Surv(time, status) ~ 1, data=lung)
survfit(sp)
sp
# Null Cox model and null Kaplan Meier are similar

# Effect of the sex on survival (factor)
sp.sex <- coxph(Surv(time, status) ~ sex.r, data = lung)
sp.sex

# Understanding the output: 

# coef: is this estimated coefficient from the model
# if coef > 1 = the risk that event occurs increases
# if coef < 1 = the risk that event occurs increases
# se(coef): coefficient standard error
# z: ratio between regression coefficient and standard error
# p: if < alpha = the covariate has a significant impact on the survival

# exp(coef): the hazard ratio  
# exp(coef) = 1 --> no effect.
# A hazards ratio of 10, on the other hand, means that the treatment group 
# has ten times the hazard of the placebo group. 
# Similarly, a HR of 1/10 implies that the treatment group has 
# one-tenth the risk of the placebo group.

# Here, the sex has a significant impact on survival (p < 0.05)
# and males have a risk which is equal to 1.7 time the risk of females

# Plot survival curves
# Using base syntax
plot(survfit(sp.sex, newdata = data.frame(sex.r = c("Male","Female"))), 
     xlab="Time", 
     ylab="S(t)",
     col=c("blue","red"))

legend("topright",
       col = c("blue", "red"),
       legend = c("Male","Female"),
       lty = c(1,1))

# Using survminer
ggadjustedcurves(sp.sex, 
                 data = lung,
                 method = "average",
                 variable = "sex.r",
                 ggtheme = theme_light())

# Effect of the age on survival (continuous covariable)
sp.age <- coxph(Surv(time, status) ~ age, data = lung)
sp.age

# Here, the age has a significant impact on survival (p < 0.05).
# (the risk of a 81 year old person = 1.01 * the risk of a 80 year old person)

# Represent survival for specific individuals
lung.new <- data.frame(age = c(50,75))
rownames(lung.new) <- paste(c(50,75), " year-old")

sp.age.surv <- survfit(sp.age, newdata = lung.new, data = lung)

ggsurvplot(sp.age.surv, 
           conf.int = TRUE, 
           censor = FALSE, 
           surv.median.line = "hv",
           ggtheme = theme_light(),
           #risk.table = T,
           legend.labs = rownames(lung.new),
           legend.title = "Age")

# -----------
# Parametric survival regression model

# Effect of the sex on survival
p.sex <- survreg(Surv(time, status) ~ sex.r, data = lung)

# Different distributions are available
?survreg.distributions

p.sex$dist

# Analysis of the output
summary(p.sex)

# Interpreting the output of survreg()
# - Distribution parameters depends on the choosen distribution (here weibull)
# --> (Intercept) = location 
# --> Log(scale) = scale

# - Coefficients
# if they are > 0 = the survival process "accelerates" 
# if they are < 0 = the survival process "decelerates" 

# Here, sex.rMale is negative, so event times 
# will occur faster for males than for females

# Comparison with Kaplan Meier curves
plot(np.sex, 
     conf.int = F, 
     ylim=c(0,1), 
     xlab="Time", 
     ylab="Healthy individuals proportion",
     col=c("blue","red"),
     lwd=2)

lines(predict(p.sex, 
              newdata = list(sex.r = "Male"),
              type = "quantile",
              p = seq(.01,.99,by = .01)),
      1-seq(.01,.99,by = .01),
      col = "black", 
      lwd = 2, 
      lty = 2)

lines(predict(p.sex, 
              newdata = list(sex.r = "Female"),
              type = "quantile",
              p = seq(.01,.99,by = .01)),
      1-seq(.01,.99,by = .01),
      col = "black", 
      lwd = 2, 
      lty = 2)

# -----------
# Predict with survival models


# Create training (70%) and test (30%) sets
# set seed for reproductibility
set.seed(123)
# train data set
train <- sample_frac(lung, 0.7) 
# test data set
test  <- anti_join(lung, 
                   train, 
                   by = names(lung)) %>% na.omit(.)

# Try with the parametric model
res.reg <- survreg(Surv(time, status) ~ ., data = train)

# Choosen distribution 
res.reg$dist

# Akaike criterion
AIC(res.reg)

# Prediction 
test.pred <- test %>% 
  mutate(pred = predict(res.reg, test, type = "response"))

ggplot(data = test.pred, 
       aes(x = time, 
           y = pred)) + 
  geom_abline(color = "red", alpha = 0.5, lty = 2) + 
  geom_point() + 
  theme_light() + 
  labs(x = "Observed survival", y = "Predicted survival")



