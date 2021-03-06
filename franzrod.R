###############################################################################
### Supplementary Does ANZROD score performs differently amongst different cohorts?
###############################################################################
library(tidyverse)
library(tableone)
library(pROC)
library(ModelMetrics)
library(ResourceSelection)
library(gbm)

dt <- readRDS("./data/franzrod.obj")

#create table 1
dt %>% select(age, sex,elect,medsurg, chr_resp:cirrhos, frailty,frail_CFS,anzrodriskofdeath,
              apache3score,apache3riskofdeath,died_icu,died_hosp,admsourc) %>% 
        tableone::CreateTableOne(vars = names(.), data = ., strata = "frail_CFS") -> tableone

tableone$ContTable %>% 
        print() %>%
        write.csv(.,"./tables_figures/table1_cont.csv")
tableone$CatTable %>% 
        print() %>%
        write.csv(.,"./tables_figures/table1_cat.csv")
rm(tableone)

#calculate table 2
roc_calculate <- function(data, i=3){
        data <- data %>% 
                filter(!is.na(died_hosp) & !is.na(anzrodriskofdeath)) %>%
                mutate(died_hosp_num = as.numeric(died_hosp)-1)
        ci<- pROC::roc(data$died_hosp, predictor = data$anzrodriskofdeath) %>% ci()
        brier <- ModelMetrics::brier(data$died_hosp_num, data$anzrodriskofdeath)
        HL_list <- ResourceSelection::hoslem.test(data$died_hosp_num, data$anzrodriskofdeath,20)
        data.frame(
                ROC = paste(median(ci) %>% round(i)),
                ROC_95CI = paste("[",quantile(ci, 0.05) %>% round(i),";",
                                 quantile(ci, 0.95) %>% round(i) ,"]"),
                Brier = brier %>% round(i),
                SMR = (sum(data$died_hosp_num)/sum(data$anzrodriskofdeath)) %>% round(i),
                Hosmer_Lemeshow = HL_list$statistic %>% as.numeric() %>% round(i)
        )
}

dt %>% 
        group_by(frail_CFS) %>% 
        do(roc_calculate(.)) %>%
        write.csv(.,"../../Franzrod/tables_figures/table2.csv")

# create figure 1
data <- dt %>% filter(frail_CFS == "non-frail")
data_pre <- dt %>% filter(frail_CFS == "pre-frail")
data_frail <- dt %>% filter(frail_CFS == "frail")
calib_plot <- function(data, replace = T, linecol = "black", df = 6, lty = 1){
        data %>% 
                filter(!is.na(died_hosp) & !is.na(anzrodriskofdeath)) %>%
                mutate(died_hosp_num = as.numeric(died_hosp)-1) -> data
        gbm::calibrate.plot(data$died_hosp, data$anzrodriskofdeath, 
                            distribution="bernoulli", replace = replace,
                            line.par = list(col = linecol), shade.col = "white",
                            shade.density = 1, rug.par = list(side = 1),
                            xlab = "ANZROD Predicted Risk of Inhospital Mortality", 
                            ylab = "Observed Inhospital Mortality", xlim = NULL,
                            ylim = NULL, knots = NULL, df = df, lty = lty)
}
calib_plot(data, df = 2)
calib_plot(data_pre, replace=F,linecol="darkgoldenrod", df = 2, lty = 2)
calib_plot(data_frail, replace=F,linecol="darkslategray4", df = 2, lty = 3)
legend("bottomright", 
       legend = c("non-frail", "pre-frail","frail"), 
       col = c("black","darkgoldenrod", "darkslategray4"),
       bty = "n", 
       cex = 1.1, 
       lty=1,
       title = "Line Types",
       text.col = c("black","darkgoldenrod", "darkslategray4"))

# Create fig 2
roc_plot <- function(data, add = F, lty=1, linecol = "black"){
        pROC::roc(data$died_hosp, predictor = data$anzrodriskofdeath) %>% 
                plot(.,add = add, lty=lty, col = linecol)
}
roc_plot(data)
roc_plot(data_pre, add = T, lty = 2, linecol = "darkgoldenrod")
roc_plot(data_frail, add = T, lty = 3, linecol ="darkslategray4")
legend("bottomright", 
       legend = c("non-frail", "pre-frail","frail"), 
       col = c("black","darkgoldenrod", "darkslategray4"),
       bty = "n", 
       cex = 1.1, 
       lty=c(1,2,3),
       title = "Line Types",
       text.col = c("black","darkgoldenrod", "darkslategray4"))
