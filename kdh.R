library(fst)             ## For Fst binary format
library(data.table)
library(lubridate)
library(magrittr)
library(stringr)         ## For str_sub: replace substr
library(parallel)
setwd("/home/whe")
jk <- read_fst("jk.fst", as.data.table = T)
t12 <- read_fst("t1_120.fst", as.data.table = T)
t13 <- read_fst("t1_130.fst", as.data.table = T)
t14 <- read_fst("t1_140.fst", as.data.table = T)
t16 <- read_fst("t1_160.fst", as.data.table = T)
t16.hp <- read_fst("t16.hp.fst", as.data.table = T)
list.AKI = list("N17")
list.o1 = list("O7020","O9991")
list.o2 = list("O7032","O7052")
list.ADVCKD = list("N183","N184","N185")
list.CKD = list("N18","N19")
list.ESRD = list("N185")
code.bm <- c("324000BIS","365900BIS","366000BIS","321400BIS","324800BIS",
           "325900BIS","326000BIS","352400BIS","321600BIS","321800BIS",
           "463700BIS","463900BIS","464000BIS","349700BIS","349900BIS",
           "423400BIS","349800BIS","350000BIS","423200BIS","350200BIS",
           "350300BIS","423500BIS","366100BIS","449000BIS","449800BIS",
           "494900BIS","513500BIS","366200BIS","449100BIS","449900BIS",
           "464700BIS","495000BIS","366300BIS","449200BIS","450000BIS",
           "464800BIS","431100BIS","431200BIS","431300BIS","509600BIS",
           "509700BIS","509800BIS","510700BIS","510800BIS","511000BIS",
           "665700BIS","665800BIS","665900BIS")


############# 공단데이터불러오기에서 자료 가져옴 ##########################
druginfo <- fread("건강보험심사평가원_의약품 주성분 정보 2019.12.csv")
t14.pre <- list(
  Smoking = c("J41", "J42", "J43", "Z72", "F17"),
  Alcohol = c("F10", "K70", "K85", "K86", "T51", "X45", "X65", "Y15", "Y91"),
  CKD = c("N18", "N19"),              ## 만성콩팥질환(Chronic kidney disease)
  HTN = paste0("I", 10:15),           ## 고혈압            
  DM = paste0("E", 10:11),            ## 당뇨
  Dyslipidemia = "E78",               ## 이상지질혈증 
  Obesity = paste0("E", 65:68),       ## 비만
  IHD = paste0("I", 20:25),           ## 허혈성심장질환(Ischemic heart disease)
  Afib = "I48",                       ## 심방세동
  CHF = "I50",                        ## 심부전(Congestive heart failure)
  Stroke = paste0("I", 60:69),        ## 뇌졸중
  Cirrhosis = "K74",                  ## 간경화
  GERD = "K21",                       ## 위식도역류질환
  G_ulcer= "K25",                     ## 위궤양
  D_ulcer = "K27"                     ## 십이지장궤양
)
t16.pre <- list(
  Statin = druginfo[grep("statin", druginfo[[3]])][`투여` == "내복"][["코드"]],
  Metformin = druginfo[grep("metformin", druginfo[[3]])][`투여` == "내복"][["코드"]],
  Aspirin = druginfo[grep("aspirin", druginfo[[3]])][`투여` == "내복"][["코드"]],
  NSAIDs_COX2 = c("347701ACH", "347701ATB", "347702ACH", "347702ATB", "347703ACH", "636401ACH", "636901ATB",
                  druginfo[grep("dexibuprofen|diclofenac|etodolac|ibuprofen|ketorolac|loxoprofen|mefenamic|nabumetone|nimesulide|sulindac|talniflumate|tiaprofenic|zaltoprofen|naproxen|meloxicam|piroxicam|lornoxicam", druginfo[[3]])][`투여` == "내복"][["코드"]]
  ),
  Clopidogrel = druginfo[grep("clopidogrel", druginfo[[3]])][`투여` == "내복"][["코드"]],
  H2RA = c("133301ATB", "133302ATB", "133303ATB", "133305ATR", "157301ATB", "157302ATB", "157302ATD", "222801ATB", "222803ATB", "222805ATB", 
           "202701ACH", "202701ATB", "202704ATB", "489302ATB", "225201ACR", "225202ACR", "271800ATB", "631800ATB"),
  PPI = c("367201ACH", "367201ATB", "367201ATD", "367202ACH", "367202ATB", "367202ATD", "498001ACH", "498002ACH", "509901ACH", "509902ACH", 
          "670700ATB", "204401ACE", "204401ATE", "204402ATE", "204403ATE", "664500ATB", "640200ATB", "664500ATB", 
          "208801ATE", "208802ATE", "656701ATE", "519201ATE", "519202ATE", "656701ATE", "519203ATE", "222201ATE", "222202ATE", "222203ATE", 
          "181301ACE", "181301ATD", "181302ACE", "181302ATD", "181302ATE", "621901ACR", "621902ACR", "505501ATE")
)
#사용해야할 데이터 불러오기

t14[, RECU_FR_DT := ymd(RECU_FR_DT)]
t14.pre.1<-unlist(t14.pre)
t14.pre.1<-unique(t14.pre.1)
t14.sym <- t14[str_sub(SICK_SYM, 1, 3) %in% t14.pre.1]

t16.pre.1<-unlist(t16.pre)
t16.pre.1<-unique(t16.pre.1)
t16.sym <- t16[GNL_NM_CD %in% t16.pre.1]
t16.sym[, RECU_FR_DT := ymd(RECU_FR_DT)]

#options("scipen"=20)
#t12[,.SD[.N],keyby="KEY_SEQ"]
#t12perkey<-t12[,.(PERSON_ID,KEY_SEQ)]
#pr<-merge(x=t13,y=t12perkey,by="KEY_SEQ",all.x=TRUE)
################## t13에 PERSON_ID 추가하기
################## t12는 PERSON_ID와 KEY_SEQ가 1:1대응. 
################## t13은 일대일 대응이 아니지만 KEY_SEQ를 하나만 남겼을 때 
################## 총 KEY_SEQ 갯수가 t12보다 적고, 
################## t12의 시작 KEY_SEQ와 종료 KEY_SEQ가 일치함.
################## 즉 t12가 t13의 모든것들을 커버 가능. 
################## but t12가 전체 표본인 것 같은데 t13에 없는 표본이 
################## AKI 등의 질병을 갖고있었을 경우가 마음에 걸림. 
t12.perkey<-t12[,.(PERSON_ID,KEY_SEQ)]
t14.sym <-
  merge(t12.perkey[KEY_SEQ %in% t14.sym$KEY_SEQ],t14.sym,by="KEY_SEQ")
t16.sym <-
  merge(t12.perkey[KEY_SEQ %in% t16.sym$KEY_SEQ],t16.sym,by="KEY_SEQ")
# t12의 PERSON_ID와 KEY_SEQ만 남김.
################### t12 정리
t12.1.hp <- 
  t12[, .(PERSON_ID, KEY_SEQ,RECU_FR_DT, MAIN_SICK,SUB_SICK)]
t12.aki.hp <- 
  t12.1.hp[str_sub(SUB_SICK, 1, 3) %in% list.AKI|str_sub(MAIN_SICK, 1, 3) %in% list.AKI]
t12.aki.hp[, AKI:=1]
#t12 에서 필요한것만 가져와서 입원치료를 요하는 AKI에 1표시
t12.advckd.hp<-t12.1.hp[str_sub(SUB_SICK, 1, 4) %in% list.ADVCKD
                        |str_sub(MAIN_SICK, 1, 4) %in% list.ADVCKD]
#t12에서 ADVCKD 조작적 정의를 만족하는 환자 추출 
t12.ckd.hp <- 
  t12.1.hp[str_sub(SUB_SICK, 1, 3) %in% list.CKD|str_sub(MAIN_SICK, 1, 3) %in% list.CKD]
#t12에서 CKD 상병코드가 주상병 or 부상병에서 발견된 환자 추출
t12.esrd.hp <- 
  t12.1.hp[str_sub(SUB_SICK, 1, 4) %in% list.ESRD|str_sub(MAIN_SICK, 1, 4) %in% list.ESRD]
#t12에서 ESRD 상병코드가 주상병 or 부상벙에서 발견된 환자 추출

################### t13정리
t13.1.hp <- t13[, .(KEY_SEQ,RECU_FR_DT, DIV_CD, MDCN_EXEC_FREQ)]
#t13에서 필요한것만 가져오기
##### t13에 PERSON_ID 묶을 도구 필요.
t13.o1.hp <- t13.1.hp[str_sub(DIV_CD, 1, 5) %in% list.o1]
t13.o2.hp <- t13.1.hp[str_sub(DIV_CD, 1, 5) %in% list.o2]
#O7020 or O9991 행위코드인 사람들은 t13.o1.hp 에 모으고 
#O7032 or O7052 행위코드인 사람들은 t13.o2.hp에 모으기.
t13.o2.hp[,o2:=1]
t13.o1.hp[,o1:=1]
#o1 임을 표시 o2 임을 표시
t13.o1.hp<-
  merge(t12.perkey[KEY_SEQ %in% t13.o1.hp$KEY_SEQ],t13.o1.hp,by="KEY_SEQ")
t13.o2.hp<-
  merge(t12.perkey[KEY_SEQ %in% t13.o2.hp$KEY_SEQ],t13.o2.hp,by="KEY_SEQ")
# t13.o1.hp와 t13.o2.hp에 KEY_SEQ 추가
t13.o2.hp[,RECU_FR_DT:=ymd(RECU_FR_DT)]
t13.o1.hp[,RECU_FR_DT:=ymd(RECU_FR_DT)]
t13.o1.hp<-t13.o1.hp[order(PERSON_ID,RECU_FR_DT,MDCN_EXEC_FREQ)]
t13.o2.hp<-t13.o2.hp[order(PERSON_ID,RECU_FR_DT)]
#날짜표기 변경 후 순서를 ID & 진단날짜 순으로 정렬
t13.o1.hp<-
  t13.o1.hp[,.(PERSON_ID, KEY_SEQ,RECU_FR_DT, DIV_CD, o1, 
               period.o1 = MDCN_EXEC_FREQ[.N]+RECU_FR_DT[.N]-RECU_FR_DT[1]), 
            keyby="PERSON_ID"][,.SD[1],keyby="PERSON_ID"]
#period.o1 로 O7020 or O9991의 행위코드 처방 일수 알수있음. 

#####################
t12.aki.hp[,RECU_FR_DT:=ymd(RECU_FR_DT)]
t12.aki.hp<-t12.aki.hp[order(PERSON_ID,RECU_FR_DT)][,.SD[1],keyby=PERSON_ID]
t12.aki.hp<-t12.aki.hp[,.(PERSON_ID,AKI,AKIDATE=RECU_FR_DT,MAIN_SICK,SUB_SICK)]
#t12.aki.hp에 PERSON_ID, AKI 처음 진단여부, 
#AKI 처음 진단받은 날짜, 주상병, 부상병 표기
t13.o2.hp<-t13.o2.hp[order(PERSON_ID,RECU_FR_DT)][,.SD[1],keyby="PERSON_ID"]
#O7032 O7052 행위코드인 사람들PERSON_ID와 첫 진단일 표시.
t13.o1.hp<-t13.o1.hp[,.(PERSON_ID,o1,period.o1,o1DATE=RECU_FR_DT)]
t13.o2.hp<-t13.o2.hp[,.(PERSON_ID,o2=1,o2DATE=RECU_FR_DT)]
#각각 첫 진단일을 o1DATE와 o2DATE로 표기 (o1DATE는 O7020 or O9991의 첫 처방일, 
#                                         o2DATE는 O7032 or O7052의 첫 처방일)
AKI<-merge(t13.o1.hp,t13.o2.hp,keyby="PERSON_ID",all=T)
AKI<-merge(AKI,t12.aki.hp,keyby="PERSON_ID",all=T)
#AKI 에 합치기

jk <- jk[order(PERSON_ID, STND_Y)]
t12 <- t12[order(PERSON_ID, RECU_FR_DT, KEY_SEQ)]
t12[, RECU_FR_DT := ymd(RECU_FR_DT)]
t12.firstcome <- t12[, .SD[1], by="PERSON_ID"]
t12.firstcome <- t12.firstcome[, .(PERSON_ID, start.come = RECU_FR_DT)]

#t16[,RECU_FR_DT:=ymd(RECU_FR_DT)]
#위에거 뻗음.
code.ppi <-  c("367201ACH", "367201ATB", "367201ATD", "367202ACH", "367202ATB", 
               "367202ATD", "498001ACH", "498002ACH", "509901ACH", "509902ACH", 
               "670700ATB", "204401ACE", "204401ATE", "204402ATE", "204403ATE", 
               "664500ATB", "640200ATB", "664500ATB", "208801ATE", "208802ATE", 
               "656701ATE", "519201ATE", "519202ATE", "656701ATE", "519203ATE", 
               "222201ATE", "222202ATE", "222203ATE", "181301ACE", "181301ATD", 
               "181302ACE", "181302ATD", "181302ATE", "621901ACR", "621902ACR", 
               "505501ATE")
code.h2ra <- c("133301ATB", "133302ATB", "133303ATB", "133305ATR", "157301ATB", 
               "157302ATB", "157302ATD", "222801ATB", "222803ATB", "222805ATB", 
               "202701ACH", "202701ATB", "202704ATB", "489302ATB", "225201ACR", 
               "225202ACR", "271800ATB", "631800ATB")
t16ppi<-t16[GNL_NM_CD %in% code.ppi]
t16h2ra<-t16[GNL_NM_CD %in% code.h2ra]
t16ppi<-merge(t12.perkey[KEY_SEQ %in% t16ppi$KEY_SEQ], t16ppi, by = "KEY_SEQ")
t16h2ra<-
  merge(t12.perkey[KEY_SEQ %in% t16h2ra$KEY_SEQ], t16h2ra, by = "KEY_SEQ")
t16ppi[, STND_Y := as.integer(str_sub(RECU_FR_DT, 1, 4))]
t16h2ra[, STND_Y := as.integer(str_sub(RECU_FR_DT, 1, 4))]
t16ppi[, RECU_FR_DT := ymd(RECU_FR_DT)]
t16h2ra[, RECU_FR_DT := ymd(RECU_FR_DT)]
freq.ppi <- merge(jk[, 1:5],t16ppi,by = c("PERSON_ID","STND_Y"))[order(PERSON_ID,RECU_FR_DT)][, .(start.ppi = RECU_FR_DT[1], period.ppi = MDCN_EXEC_FREQ[.N] + RECU_FR_DT[.N] - RECU_FR_DT[1], dsum.ppi = sum(MDCN_EXEC_FREQ)), keyby = "PERSON_ID"][, freq.ppi := dsum.ppi/as.integer(period.ppi)][,-c("dsum.ppi")]
freq.h2ra <- merge(jk[, 1:5], t16h2ra, by = c("PERSON_ID","STND_Y"))[order(PERSON_ID,RECU_FR_DT)][, .(start.h2ra = RECU_FR_DT[1], period.h2ra = MDCN_EXEC_FREQ[.N] + RECU_FR_DT[.N] - RECU_FR_DT[1], dsum.h2ra = sum(MDCN_EXEC_FREQ)), keyby = "PERSON_ID"][, freq.h2ra := dsum.h2ra/as.integer(period.h2ra)][,-c("dsum.h2ra")]
# 제균치료 반영 안됨. 모든 사람들 가지고 한것. 기존 out.hp 만드는 과정과 동일 + order(PERSON_ID,RECU_FR_DT) 추가
# freq.ppi[,STND_Y:=as.integer(str_sub(start.ppi,1,4))]
jk[, STND_Y := as.integer(STND_Y)]

out.hp <- merge(t12.firstcome, freq.ppi, by="PERSON_ID", all = T)
out.hp <- merge(out.hp, freq.h2ra, by="PERSON_ID", all = T)
#####################################
#freq.ppi[, STND_Y := as.integer(str_sub(start.ppi, 1, 4))]
#freq.h2ra[, STND_Y := as.integer(str_sub(start.h2ra, 1, 4))]
#freq.ppi[, STND_Y := as.integer(STND_Y)]
#out.hp <- merge(jk[PERSON_ID %in% freq.ppi$PERSON_ID][order(PERSON_ID,STND_Y)][, 1:5], 
#                freq.ppi, by=c("PERSON_ID","STND_Y"))
#out.hp <- merge(out.hp, freq.h2ra, key="PERSON_ID", all=T)
#####################################
######20200703ㅇㅔ 없앰
#####################################
# jk 에서 첫 기준년도만 남기고 freq.ppi 와 합치기.
####### 기준년도에 따라 달라질듯.
out.hp$period.ppi[is.na(out.hp$period.ppi)] <- 0
out.hp$period.h2ra[is.na(out.hp$period.h2ra)] <- 0
# NA 제거
# out.hp <- out.hp[period.ppi != 0 | period.h2ra != 0][period.ppi == 0 | period.h2ra == 0]
# 대조군과 실험군만을 남기고 모두 out.hp에서 삭제

####################################
   #위에서 만든 out.hp 사용#
####################################
AKI <- AKI[, .(PERSON_ID, o1, 
               period.o1, 
               start.o1 = o1DATE, 
               o2, 
               start.o2 = o2DATE, 
               AKI, 
               start.AKI = AKIDATE, 
               MAIN_SICK, 
               SUB_SICK)]
AKI <- merge(AKI, out.hp, keyby="PERSON_ID", all=T)
AKI$o1[is.na(AKI$o1)] <- 0
AKI$o2[is.na(AKI$o2)] <- 0
AKI$AKI[is.na(AKI$AKI)] <- 0


# AKI[date+(숫자)<AKIDATE] 를 통해 PPI 처방 (숫자)일 후 AKI 상병코드 발생 환자 추출 가능
# 추출 후 AKI가 1이면 -> 입원치료를 요하는 AKI
# AKI * o1 이 1이면-> 투석치료를 요하는 AKI
# AKI * o2 이 1이면-> 2일 이상의 CRRT 치료를 요하는 AKI

t12.ckd.hp[, RECU_FR_DT := ymd(RECU_FR_DT)]
t12.advckd.hp[, RECU_FR_DT := ymd(RECU_FR_DT)]
t12.ckd.hp<-
  t12.ckd.hp[, .(PERSON_ID, CKD=1, CKDDATE=RECU_FR_DT, MAIN_SICK, SUB_SICK)]
t12.advckd.hp<-
  t12.advckd.hp[, .(PERSON_ID, 
                    ADVCKD=1, 
                    ADVCKDDATE=RECU_FR_DT, 
                    MAIN_SICK, 
                    SUB_SICK)]
t12.ckd.hp <- t12.ckd.hp[order(PERSON_ID, CKDDATE)][, .SD[1], keyby="PERSON_ID"]
t12.advckd.hp <- 
  t12.advckd.hp[order(PERSON_ID, ADVCKDDATE)][, .SD[1], keyby="PERSON_ID"]

t12.ckd.hp <- t12.ckd.hp[, .(PERSON_ID, CKD, start.CKD = CKDDATE, MAIN_SICK,
                              SUB_SICK)]
t12.advckd.hp <- t12.advckd.hp[, .(PERSON_ID, ADVCKD, start.ADVCKD = ADVCKDDATE,
                                   MAIN_SICK, SUB_SICK)]

#CKD와 ADVCKD 첫 진단 날짜 추출 & ADVCKD 와  CKD 있는 여부 체크하는 열 추가
CKD <- merge(t12.ckd.hp, out.hp, keyby="PERSON_ID", all = T)
CKD <- merge(t12.advckd.hp, CKD, keyby="PERSON_ID", all = T)
#개인정보 있는 곳 out.hp와 합치기
CKD$CKD[is.na(CKD$CKD)] <- 0
CKD$ADVCKD[is.na(CKD$ADVCKD)] <- 0
# CKD[date+(숫자)<CKDDATE] 를 통해 PPI 처방 (숫자)일 후 CKD 상병코드 발생 환자 추출 가능
# ADVCKD[date+(숫자)<ADVCKDDATE] 를 통해 PPI 처방 (숫자)일 후 advanced CKD 상병코드 발생 환자 추출 가능
# CKD =1 이면 -> CKD 상병코드가 주상병/부상병에 발생한 환자
# ADVCKD =1 이면 -> ADVCKD 상병코드가 주상병/부상병에 발생한 환자
# CKD가 ADVCKD를 포함함

t12.esrd.hp[, RECU_FR_DT := ymd(RECU_FR_DT)]
t12.esrd.hp <- t12.esrd.hp[order(PERSON_ID, RECU_FR_DT)][, .SD[1], 
                                                         keyby=PERSON_ID]
# ESRD 상병코드를 가진 환자들만 모아서 최초 진단일만 남김
t12.esrd.hp<-
  t12.esrd.hp[, .(PERSON_ID, N185=1, N185DATE=RECU_FR_DT, MAIN_SICK, SUB_SICK)]
#PERSON_ID, N185를 가졌는지 여부 표시, N1185 첫 진단일을 N185DATE로 정리
ESRD <- merge(t12.esrd.hp, t13.o1.hp, keyby="PERSON_ID", all=T)
ESRD$N185[is.na(ESRD$N185)] <- 0
#ESRD에 N185 여부와 첫 날짜, O7020 or O9991 여부를 알 수 있는 정보를 합침


t16.esrd <- t16[GNL_NM_CD %in% code.bm]
t16.esrd[, RECU_FR_DT := ymd(RECU_FR_DT)]
t16.esrd <- merge(t12.perkey[KEY_SEQ %in% t16.esrd$KEY_SEQ], t16.esrd, 
                  by="KEY_SEQ")
#PERSON_ID 추가
t16.esrd <- t16.esrd[order(PERSON_ID, RECU_FR_DT, MDCN_EXEC_FREQ)]
#t16에서 ESRD에 해당하는 약물코드를 포함하는 자료만 얻어냄

t16.esrd[, period.bm := MDCN_EXEC_FREQ[.N]+RECU_FR_DT[.N]-RECU_FR_DT[1], 
         keyby="PERSON_ID"]
t16.esrd <- t16.esrd[order(PERSON_ID, RECU_FR_DT, KEY_SEQ)][, .SD[1], keyby="PERSON_ID"][, .(PERSON_ID, period.bm)]


#t16.esrd<-t16.esrd[,.(PERSON_ID,period.bm=MDCN_EXEC_FREQ[.N]+RECU_FR_DT[.N]-RECU_FR_DT[1],keyby="PERSON_ID")][,.SD[1],keyby=PERSON_ID]
#t16.esrd에 PERSON_ID, period.bm을 남김, period.bm은 해당 약물코드 처방 기간.
ESRD <- merge(ESRD, t16.esrd, keyby="PERSON_ID", all=T)
#ESRD에 약물코드 자료 합치기
ESRD$period.o1[is.na(ESRD$period.o1)] <- 0
ESRD$period.bm[is.na(ESRD$period.bm)] <- 0
ESRD[, ESRD:=ifelse(N185 == 1,
                    ifelse(period.o1 >= 90,
                           1, 
                           ifelse(period.bm >= 90, 
                                  1, 
                                  0)),
                    0)]
#주상병이나 부상병에 N185있으면서 O7020 O9991이 90일(3개월) 이상이거나, 복막투석액 처방코드가 90일 이상인 경우 ESRD열에 1로 표시, 나머지는 0으로 표시
ESRD$ESRD[is.na(ESRD$ESRD)] <- 0
#NA여서 ifelse이후 NA로 나오는 놈들 모두 0으로 변경
ESRD <- merge(out.hp, ESRD, keyby="PERSON_ID", all=T)
#자격 DB와 함치기
ESRD$ESRD[is.na(ESRD$ESRD)] <- 0
#자격 DB에서 ESRD가 없던 것들이 NA였는데 이들을 0으로 변경
#ESRD가 1이면 ESRD０이면 ESRD 아님

# AKI <- AKI[period.ppi != 0 | period.h2ra != 0][period.ppi == 0 | period.h2ra == 0]
# CKD <- CKD[period.ppi != 0 | period.h2ra != 0][period.ppi == 0 | period.h2ra == 0]
# ESRD <- ESRD[period.ppi != 0 | period.h2ra != 0][period.ppi == 0 | period.h2ra == 0]
# 대조군과 실험군만 빼고 나머지 삭제
# PPI, H2RA 둘다 먹은 군도 살리기로 해서 취소

#AKI[AKIDATE<=start.ppi+365]$AKI<-0
# PPI 처방시점 1년 이후에 AKI 상병코드 발생한 경우만 살리고 나머지는 AKI=0
#CKD[CKDDATE<=start.ppi+365]$CKD<-0
#CKD[ADVCKDDATE<=start.ppi+365]$ADVCKD<-0
#PPI 처방 이후 1년 후에 CKD or ADVCKD 발생한 환자 빼고 CKD =0 ADVCKD=0

#fwrite(AKI, "AKI.csv")
#fwrite(CKD, "CKD.csv")
#fwrite(ESRD, "ESRD.csv")
#저장

TOT <- merge(AKI[, .(PERSON_ID, o1,period.o1, start.o1, o2, start.o2, AKI, 
                     start.AKI, start.ppi, period.ppi, freq.ppi, start.h2ra,
                     period.h2ra, freq.h2ra)], 
             CKD[, .(PERSON_ID, ADVCKD, start.ADVCKD, CKD, start.CKD)],
             keyby="PERSON_ID")
TOT <- merge(TOT, ESRD[, .(PERSON_ID, period.bm, ESRD)])
TOT <- merge(TOT, t12.firstcome, by="PERSON_ID", all=T)
#한곳으로 모으기
#입원치료 AKI-> AKI1, 투석치료AKI-> AKI2, 2일이상 CRRTAKI->AKI3  ///

TOT$period.o1[is.na(TOT$period.o1)] <- 0
TOT$period.bm[is.na(TOT$period.bm)] <- 0


#SIMPLETOT<-TOT[,.(PERSON_ID,AKI1=AKI,AKI2=AKI*o1,AKI3=AKI*o2,CKD,ADVCKD,ESRD,STND_Y,SEX,AGE_GROUP,DTH_YM,start.ppi,period.ppi,freq.ppi)]
#간편보기, 
#fwrite(TOT, "TOT.csv")
#fwrite(SIMPLETOT, "SIMPLETOT.csv")
##################################################
##################################################





  


#ISTHISAKICKDTOT<-function(x,y){
#    AKITEMP<-AKI
#    AKITEMP[AKIDATE<=start.ppi+x]$AKI<-0
#    AKITEMP[is.na(start.ppi)]$AKI<-0
#    CKDTEMP<-CKD
#    CKDTEMP[CKDDATE<=start.ppi+y]$CKD<-0
#    CKDTEMP[ADVCKDDATE<=start.ppi+y]$ADVCKD<-0
#    CKDTEMP[is.na(start.ppi)]$CKD<-0
#    CKDTEMP[is.na(start.ppi)]$ADVCKD<-0
#    ppi.TOT<-merge(AKITEMP[,.(PERSON_ID,o1,period.o1,o1DATE,o2,o2DATE,AKI,AKIDATE,STND_Y,SEX,AGE_GROUP,DTH_YM,start.ppi,period.ppi,freq.ppi)],CKDTEMP[,.(PERSON_ID,ADVCKD,ADVCKDDATE,CKD,CKDDATE)],keyby="PERSON_ID")
#    ppi.TOT<-merge(ppi.TOT,ESRD[,.(PERSON_ID,period.bm,ESRD)])
#    ppi.SIMPLETOT<-ppi.TOT[,.(PERSON_ID,AKI1=AKI,AKI2=AKI*o1,AKI3=AKI*o2,CKD,ADVCKD,ESRD,STND_Y,SEX,AGE_GROUP,DTH_YM,start.ppi,period.ppi,freq.ppi,AKIDATE,ADVCKDDATE,CKDDATE)]
#    return(ppi.TOT)
#}
#ISTHISAKICKDSIMPLETOT<-function(x,y){
#  AKITEMP<-AKI
#  AKITEMP[AKIDATE<=start.ppi+x]$AKI<-0
#  AKITEMP[is.na(start.ppi)]$AKI<-0
#  CKDTEMP<-CKD
#  CKDTEMP[CKDDATE<=start.ppi+y]$CKD<-0
#  CKDTEMP[ADVCKDDATE<=start.ppi+y]$ADVCKD<-0
#  CKDTEMP[is.na(start.ppi)]$CKD<-0
#  CKDTEMP[is.na(start.ppi)]$ADVCKD<-0
#  ppi.TOT<-merge(AKITEMP[,.(PERSON_ID,o1,period.o1,o1DATE,o2,o2DATE,AKI,AKIDATE,STND_Y,SEX,AGE_GROUP,DTH_YM,start.ppi,period.ppi,freq.ppi)],CKDTEMP[,.(PERSON_ID,ADVCKD,ADVCKDDATE,CKD,CKDDATE)],keyby="PERSON_ID")
#  ppi.TOT<-merge(ppi.TOT,ESRD[,.(PERSON_ID,period.bm,ESRD)])
#  ppi.SIMPLETOT<-ppi.TOT[,.(PERSON_ID,AKI1=AKI,AKI2=AKI*o1,AKI3=AKI*o2,CKD,ADVCKD,ESRD,STND_Y,SEX,AGE_GROUP,DTH_YM,start.ppi,period.ppi,freq.ppi,AKIDATE,ADVCKDDATE,CKDDATE)]
#  return(ppi.SIMPLETOT)
#}

##### ISTHISAKICKDTOT(x,y)  입력시 ppi 처방 안 받은 사람들과 처방시점+x일 이전(>=)에 AKI 상병코드 최초 발생한 환자는 AKI =0
#####                           ppi 처방 안 받은 사람들과 처방시점+y일 이전(>=)에 CKD 상병코드 최초 발생한 환자는 CKD =0 / ADVCKD 상병코드 최초 발생자는 ADVCKD =0
##### ISTHISAKICKDSIMPLETOT(x,y)   ISTHISAKICKDTOT(x,y)와 동일하나 정리된 모양

pr <- HTA(1,365,365)
pr[,STND_Y := as.integer(str_sub(indexdate,1,4))]
pr<-merge(pr,jk[PERSON_ID %in% pr$PERSON_ID],by=c("PERSON_ID","STND_Y"))

pr <- fread("pr.csv")
tb.chi <- table(pr[,.(EXPCON, SEX)])
chisq.test(tb.chi)
tb.chi <- table(pr[,.(EXPCON, AKI)])
chisq.test(tb.chi)
pr.ttest <- t.test(pr[EXPCON==1]$period.bm,pr[EXPCON==2]$period.bm)
pr.ttest


pr2 <- HTA(2,365,365)
pr2[,STND_Y := as.integer(str_sub(indexdate,1,4))]
pr2<-merge(pr2,jk[PERSON_ID %in% pr$PERSON_ID],by=c("PERSON_ID","STND_Y"))
tb.chi <- table(pr2[,.(EXPCON, SEX)])
chisq.test(tb.chi)
tb.chi <- table(pr2[,.(EXPCON, AKI)])
chisq.test(tb.chi)
pr.ttest <- t.test(pr2[EXPCON==1]$period.bm,pr2[EXPCON==2]$period.bm)
pr.ttest

