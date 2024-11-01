#### LINUX
# VULCAN's Optivum lesson plan
## Checks and notify if change lesson plans.
This is paid plan which buy polish schools at [Vulcan site](https://www.vulcan.edu.pl/programy) to generate lesson plans.

## **Config first**
Rename config file **plancheckcfg** to prepend with dot and fill with.

### Mail
```
mailssl=
mailsmtp='mailserver:port'
mailuser=
mailpass='password4mailfrom'
mailfrom='mailfrom@adress'
mailto='mailto@adress'
```
- mailssl : if no SSL just leave blank
- mailuser : leave blank if same as mailfrom

**NOTICE** In case ```curl: (67) Login denied``` need check mailuser and mailpass.


### Styling
htmlstyle : it is preconfigured but if you want change for exp. colors then just edit

### List active
```
planactv=("20220901" "20230624")
```
Between this date lesson plans will be checked. First is begin date (format YYYYMMDD) and second is end.

### List
```
planlist=(
"ZS16;https://zs16.edu.bydgoszcz.pl/plan-lekcji;5d"
"ZS16;;7a"
"ZSM2;https://www.zsmnr2.pl/zsm/plan-lekcji;3TDp"
";;1TCp"
"ZS10;https://sp31.bydgoszcz.pl/plan/plany/o14.html;4c"
)
```
Each entry in list consists of 3 items separated by a semicolon. The first example above is for new api and last is for old api.
Leaving empty field, like in 2 and 3 line, means use of last value from previews line.
Last item is class ID in case when data under url not belong to it.

To get links for first just copy from adress bar, for last copy link from left panel.

### Web Page
Directory **www** contains HTML files for public access. This direcory can be symlinked or synced to actual domain directory. HTML body/styles/script are put inside script with no external config. File **template.html** contains page skeleton. If you wish not generate HTMLs just remove **www** dir or leave this blank:
```
htmlwww=
```


## Get links

**2.0** Just copy from adress bar.

![2.0](volcan_api_2.png)


**1.0** Copy link from left panel (left click and Copy Link).

![1.0](volcan_api_1.png)

## Install and run
Just put on any linux server or host with shell. Set execute flag on script with **chmod +x**. Set it to run as cron job.

### Args
- -m -> force send mail
- -u -> just update and no sending mail.
