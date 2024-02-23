#!/bin/bash
# Current logged in user
currentUser=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')
# Required date on which the update must be installed. Date format YYYYMMDD
UPDATE_DEADLINE=20240201
readonly UPDATE_DEADLINE
# Current date on the device
CURRENT_DATE=$(date +"%Y%m%d")
# Current date and hour on the device
CURRENT_HOUR=$(date +"%Y%m%d%H%M")
# Current OS version
OS_VERSION=$(/usr/bin/sw_vers -productVersion)
# Current major OS Version
OS_MAJOR_VERSION=$(/usr/bin/sw_vers -productVersion | cut -d '.' -f 1)
readonly OS_VERSION
# Define buffer for comparing macOS Versions
VER_CHECK="0"
readonly OS_MAJOR_VERSION
# Last Bayer compliant OS Version
VENTURA_VERS="13.6.4"
readonly VENTURA_VERS
SONOMA_VERS="14.3.1"
readonly SONOMA_VERS
# IBM Notifier folders and binary
MACOS_UPGRADE_FOLDER="/Library/Management/macOS_upgrade"
readonly MACOS_UPGRADE_FOLDER
IBM_NOTIFIER_APP="/Library/Management/macOS_upgrade/IBM Notifier.app"
readonly IBM_NOTIFIER_APP
IBM_NOTIFIER_BINARY="/Library/Management/macOS_upgrade/IBM Notifier.app/Contents/MacOS/IBM Notifier"
readonly IBM_NOTIFIER_BINARY
IBM_NOTIFIER_SUPER="/Library/Management/super/IBM Notifier.app/Contents/MacOS/IBM Notifier"
readonly IBM_NOTIFIER_SUPER
# macOS Upgrade Deferral
MACOS_UPGRADE_DEFERRAL="${MACOS_UPGRADE_FOLDER}/deferral"
# URL to the IBM Notifier.app download:
IBM_NOTIFIER_DOWNLOAD_URL="https://github.com/IBM/mac-ibm-notifications/releases/download/v-3.1.0-b-110/IBM.Notifier.zip"
readonly IBM_NOTIFIER_DOWNLOAD_URL
# Logo Icon Path
BAYER_LOGO="https://shared.bayer.com/img/bayer-logo.png"
readonly BAYER_LOGO
# Upgrade log folder
UPGRADE_LOG_FOLDER="${MACOS_UPGRADE_FOLDER}/logs"
readonly UPGRADE_LOG_FOLDER
# Upgrade log file
UPGRADE_LOG="${UPGRADE_LOG_FOLDER}/upgrade.log"
readonly UPGRADE_LOG
# IBM Notifier constants
TYPE="popup"
readonly TYPE
BAR_TITLE="Bayer AG"
readonly BAR_TITLE
TITLE="Update/Upgrade your Mac"
readonly TITLE
PRIMARY_ACCESSORY_TYPE="html"
readonly PRIMARY_ACCESSORY_TYPE
ACCESSORY_VIEW_PAYLOAD="<div style=\"overflow-y: hidden;\"><p style=\"font-size: 12px; font-family: -apple-system-body, BlinkMacSystemFont, sans-serif;\"><strong>Bayer macOS Upgrade</strong> is attempting to restart your Mac in order to update it to the latest approved macOS version to ensure it stays <strong>secure and compliant</strong>.</p><p style=\"font-size: 12px; font-family: -apple-system-body, BlinkMacSystemFont, sans-serif;\">The restart can take up to 15 minutes.</p><p style=\"font-size: 12px; font-family: -apple-system-body, BlinkMacSystemFont, sans-serif;margin-bottom: 0px\">You can choose to restart now via the <strong>Restart</strong> button below or <strong>defer</strong> this notice up to 5 times to a time that is convenient for you. <strong>After the last deferral, you must restart your Mac</strong> to apply the update.</p><p style=\"font-size: 12px; font-family: -apple-system-body, BlinkMacSystemFont, sans-serif;margin-top: 0px;\">You can also initiate the restart from the <em>Software Update</em> section of <em>System Settings</em> at any time. The update has already been prepared for you in the background.</p></div>"
readonly ACCESSORY_VIEW_PAYLOAD
SECOND_ACCESSORY_TYPE="dropdown"
readonly SECOND_ACCESSORY_TYPE
SECONDARY_ACCESSORY_PAYLOAD="/list 1 hour\n2 hours\n4 hours\n8 hours\n10 hours\n12 hours\n1 day /selected 0"
readonly SECONDARY_ACCESSORY_PAYLOAD
HELP_BUTTON_PAYLOAD="https://bayersi.service-now.com/sp?id=sc_cat_item_2&sys_id=999e98bcdb87df0074e7dcd74896193f&sysparm_category=e15706fc0a0a0aa7007fc21e1ab70c2f"
readonly HELP_BUTTON_PAYLOAD
MAIN_BUTTON_LABEL="Defer"
readonly MAIN_BUTTON_LABEL
SECONDARY_BUTTON_LABEL="Upgrade Now"
readonly SECONDARY_BUTTON_LABEL
# Initialising USER_OPTION global variable
USER_OPTION=""
# Initialisaing PASS
PASS=""

log_upgrade() {
   echo -e "$(date +"%a %b %d %T") $(hostname -s) $(basename "$0")[$$]: $*" | tee -a "${UPGRADE_LOG}"
}

check_versions(){
    if [[ $1 == $2 ]]; then
        VER_CHECK="0"
    else
        low=$(echo -e "$1\n$2" | sort --version-sort | head --lines=1)
        if [[ $low == $1 ]]; then
            VER_CHECK="1"
        else
            VER_CHECK="0"
        fi
    fi
}

get_ibm_notifier_upgrade() {
   local TEMP_FILE
   local CURL_RESPONSE
   TEMP_FILE="$(mktemp).zip"
   CURL_RESPONSE=$(curl --location "${IBM_NOTIFIER_DOWNLOAD_URL}" --output "${TEMP_FILE}" 2>&1)
   if [[ -f "${TEMP_FILE}" ]]; then
      local UNZIP_RESPONSE
      UNZIP_RESPONSE=$(unzip "${TEMP_FILE}" -d "${IBM_NOTIFIER_FOLDER}/" 2>&1)
      if [[ -d "${IBM_NOTIFIER_APP}" ]]; then
         [[ -d "${IBM_NOTIFIER_FOLDER}/__MACOSX" ]] && rm -Rf "${IBM_NOTIFIER_FOLDER}/__MACOSX" > /dev/null 2>&1
         chmod -R a+rx "${IBM_NOTIFIER_APP}"
         rm -Rf "${TEMP_FILE}" > /dev/null 2>&1
         USER_OPTION=$("${IBM_NOTIFIER_BINARY}" -type "${TYPE}" -bar_title "${BAR_TITLE}" -title "${TITLE}" -icon_path "${BAYER_LOGO}" -accessory_view_type "${PRIMARY_ACCESSORY_TYPE}" -accessory_view_payload "${ACCESSORY_VIEW_PAYLOAD}" -secondary_accessory_view_type ${SECOND_ACCESSORY_TYPE} -secondary_accessory_view_payload "${SECONDARY_ACCESSORY_PAYLOAD}" -help_button_cta_type link -help_button_cta_payload "${HELP_BUTTON_PAYLOAD}" -main_button_label "${MAIN_BUTTON_LABEL}" -secondary_button_label "${SECONDARY_BUTTON_LABEL}" -secondary_button_cta_type exitlink -silent -position center)
      else
         log_upgrade "Unable to install (unzip) IBM Notifier.app - sending notifications with hubcli notify"
         USER_OPTION="5"
         /usr/local/bin/hubcli notify -t "Update to the latest approved macOS Version" -s "This may take up to 1 hour." -i "Your machine will restart automatically. You will be notified when your device will be restarted. You have until Feb. 28th to update your device." -a "Begin" -b "/usr/local/bin/hubcli mdmcommand --osupdate --productversion 14.3.1 --installaction InstallASAP" -c "Update Later"
      fi
   else
      log_upgrade "Unable to download IBM Notifier.app (CURL) - sending notifications with hubcli notify"
      USER_OPTION="5"
      /usr/local/bin/hubcli notify -t "Update to the latest approved macOS Version" -s "This may take up to 1 hour." -i "Your machine will restart automatically. You will be notified when your device will be restarted. You have until Feb. 28th to update your device." -a "Begin" -b "/usr/local/bin/hubcli mdmcommand --osupdate --productversion 14.3.1 --installaction InstallASAP" -c "Update Later"
   fi
}

send_upgrade_notification() {
   if [[ -e ${IBM_NOTIFIER_SUPER} ]]; then
      log_upgrade "IBM Notifier app already installed from SUPER, sending notification"
      USER_OPTION=$("${IBM_NOTIFIER_SUPER}" -type "${TYPE}" -bar_title "${BAR_TITLE}" -title "${TITLE}" -icon_path "${BAYER_LOGO}" -accessory_view_type "${PRIMARY_ACCESSORY_TYPE}" -accessory_view_payload "${ACCESSORY_VIEW_PAYLOAD}" -secondary_accessory_view_type ${SECOND_ACCESSORY_TYPE} -secondary_accessory_view_payload "${SECONDARY_ACCESSORY_PAYLOAD}" -help_button_cta_type link -help_button_cta_payload "${HELP_BUTTON_PAYLOAD}" -main_button_label "${MAIN_BUTTON_LABEL}" -secondary_button_label "${SECONDARY_BUTTON_LABEL}" -secondary_button_cta_type exitlink -silent -position center)
   elif [[ -e ${IBM_NOTIFIER_APP} ]]; then
      log_upgrade "IBM Notifier app already installed from sensor, sending notification"
      USER_OPTION=$("${IBM_NOTIFIER_BINARY}" -type "${TYPE}" -bar_title "${BAR_TITLE}" -title "${TITLE}" -icon_path "${BAYER_LOGO}" -accessory_view_type "${PRIMARY_ACCESSORY_TYPE}" -accessory_view_payload "${ACCESSORY_VIEW_PAYLOAD}" -secondary_accessory_view_type ${SECOND_ACCESSORY_TYPE} -secondary_accessory_view_payload "${SECONDARY_ACCESSORY_PAYLOAD}" -help_button_cta_type link -help_button_cta_payload "${HELP_BUTTON_PAYLOAD}" -main_button_label "${MAIN_BUTTON_LABEL}" -secondary_button_label "${SECONDARY_BUTTON_LABEL}" -secondary_button_cta_type exitlink -silent -position center)
   else
      log_upgrade "IBM Notifier not installed, fetching it via get_ibm_notifier function"
      get_ibm_notifier_upgrade
   fi
   case ${USER_OPTION} in
      0)
         log_upgrade "User defered for 1 hour, adjusting deferral file and closing"
         USER_DEFERRAL_NEW_HOUR=$(date "-v+1H" "+%Y%m%d%H%M")
         sed -i '' -e '1 s/.*/'"${USER_DEFERRAL_NEW_HOUR}"'/' "${MACOS_UPGRADE_DEFERRAL}"
         USER_DEFERRAL_NEW_REMAINING=$((USER_DEFERRAL_REMAINING - 1))
         sed -i '' -e '2 s/.*/'"${USER_DEFERRAL_NEW_REMAINING}"'/' "${MACOS_UPGRADE_DEFERRAL}"
         exit 0
         ;;
      1)
         log_upgrade "User defered for 2 hour, adjusting deferral file and closing"
         USER_DEFERRAL_NEW_HOUR=$(date "-v+2H" "+%Y%m%d%H%M")
         sed -i '' -e '1 s/.*/'"${USER_DEFERRAL_NEW_HOUR}"'/' "${MACOS_UPGRADE_DEFERRAL}"
         USER_DEFERRAL_NEW_REMAINING=$((USER_DEFERRAL_REMAINING - 1))
         sed -i '' -e '2 s/.*/'"${USER_DEFERRAL_NEW_REMAINING}"'/' "${MACOS_UPGRADE_DEFERRAL}"
         exit 0
         ;;
      2)
         log_upgrade "User defered for 4 hour, adjusting deferral file and closing"
         USER_DEFERRAL_NEW_HOUR=$(date "-v+4H" "+%Y%m%d%H%M")
         sed -i '' -e '1 s/.*/'"${USER_DEFERRAL_NEW_HOUR}"'/' "${MACOS_UPGRADE_DEFERRAL}"
         USER_DEFERRAL_NEW_REMAINING=$((USER_DEFERRAL_REMAINING - 1))
         sed -i '' -e '2 s/.*/'"${USER_DEFERRAL_NEW_REMAINING}"'/' "${MACOS_UPGRADE_DEFERRAL}"
         exit 0
         ;;
      3)
         log_upgrade "User defered for 8 hour, adjusting deferral file and closing"
         USER_DEFERRAL_NEW_HOUR=$(date "-v+8H" "+%Y%m%d%H%M")
         sed -i '' -e '1 s/.*/'"${USER_DEFERRAL_NEW_HOUR}"'/' "${MACOS_UPGRADE_DEFERRAL}"
         USER_DEFERRAL_NEW_REMAINING=$((USER_DEFERRAL_REMAINING - 1))
         sed -i '' -e '2 s/.*/'"${USER_DEFERRAL_NEW_REMAINING}"'/' "${MACOS_UPGRADE_DEFERRAL}"
         exit 0
         ;;
      4)
         log_upgrade "User defered for 10 hour, adjusting deferral file and closing"
         USER_DEFERRAL_NEW_HOUR=$(date "-v+10H" "+%Y%m%d%H%M")
         sed -i '' -e '1 s/.*/'"${USER_DEFERRAL_NEW_HOUR}"'/' "${MACOS_UPGRADE_DEFERRAL}"
         USER_DEFERRAL_NEW_REMAINING=$((USER_DEFERRAL_REMAINING - 1))
         sed -i '' -e '2 s/.*/'"${USER_DEFERRAL_NEW_REMAINING}"'/' "${MACOS_UPGRADE_DEFERRAL}"
         exit 0
         ;;
      5)
         log_upgrade "User defered for 12 hour, adjusting deferral file and closing"
         USER_DEFERRAL_NEW_HOUR=$(date "-v+12H" "+%Y%m%d%H%M")
         sed -i '' -e '1 s/.*/'"${USER_DEFERRAL_NEW_HOUR}"'/' "${MACOS_UPGRADE_DEFERRAL}"
         USER_DEFERRAL_NEW_REMAINING=$((USER_DEFERRAL_REMAINING - 1))
         sed -i '' -e '2 s/.*/'"${USER_DEFERRAL_NEW_REMAINING}"'/' "${MACOS_UPGRADE_DEFERRAL}"
         exit 0
         ;;
      6)
         log_upgrade "User defered for 24 hour, adjusting deferral file and closing"
         USER_DEFERRAL_NEW_HOUR=$(date "-v+24H" "+%Y%m%d%H%M")
         sed -i '' -e '1 s/.*/'"${USER_DEFERRAL_NEW_HOUR}"'/' "${MACOS_UPGRADE_DEFERRAL}"
         USER_DEFERRAL_NEW_REMAINING=$((USER_DEFERRAL_REMAINING - 1))
         sed -i '' -e '2 s/.*/'"${USER_DEFERRAL_NEW_REMAINING}"'/' "${MACOS_UPGRADE_DEFERRAL}"
         exit 0
         ;;   
      *)
         log_upgrade "User has not selected anything - repeating in 1h decreasing deferrals remaining"
         USER_DEFERRAL_NEW_HOUR=$(date "-v+1H" "+%Y%m%d%H%M")
         sed -i '' -e '1 s/.*/'"${USER_DEFERRAL_NEW_HOUR}"'/' "${MACOS_UPGRADE_DEFERRAL}"
         USER_DEFERRAL_NEW_REMAINING=$((USER_DEFERRAL_REMAINING - 1))
         sed -i '' -e '2 s/.*/'"${USER_DEFERRAL_NEW_REMAINING}"'/' "${MACOS_UPGRADE_DEFERRAL}"
         exit 0
         ;;
   esac
}

send_password_notification() {
   if [[ -e ${IBM_NOTIFIER_SUPER} ]]; then
      PASS=$("${IBM_NOTIFIER_SUPER}" -type "${TYPE}" -bar_title "${BAR_TITLE}" -title "${TITLE}" -subtitle "Enter your login password to start the update process" -icon_path "${BAYER_LOGO}" -accessory_view_type secureinput -accessory_view_payload "/placeholder Enter password /title Password /required" -main_button_label "OK" -silent -position center)
   elif [[ -e ${IBM_NOTIFIER_APP} ]]; then
      PASS=$("${IBM_NOTIFIER_APP}" -type "${TYPE}" -bar_title "${BAR_TITLE}" -title "${TITLE}" -subtitle "Enter your login password to start the update process" -icon_path "${BAYER_LOGO}" -accessory_view_type secureinput -accessory_view_payload "/placeholder Enter password /title Password /required" -main_button_label "OK" -silent -position center)
   fi
}

# Check if log file exists, create it if not
if [[ -e "${UPGRADE_LOG}" ]];then
   log_upgrade "Log file exists, continuing"
else
   log_upgrade "Log file is missing, creating it and continuing"
   mkdir -p "${UPGRADE_LOG_FOLDER}"
   touch "${UPGRADE_LOG}"
fi

log_upgrade "######################## Starting new upgrade attempt ########################"
log_upgrade "Starting..."

# Check if deferral file exists, create if not
if [[ -e "${MACOS_UPGRADE_DEFERRAL}" ]]; then
   log_upgrade "Deferral file exists, continuing"
else
   log_upgrade "Deferral file missing, creating and continuing"
   touch "${MACOS_UPGRADE_DEFERRAL}"
   echo -e "${CURRENT_HOUR}\n5" | tee -a "${MACOS_UPGRADE_DEFERRAL}"
fi

if [[ ${OS_MAJOR_VERSION} -eq 13 ]]; then
   check_versions "${OS_VERSION}" "${VENTURA_VERS}"
else
   check_versions "${OS_VERSION}" "${SONOMA_VERS}"
fi

# Compares current date to the required install date
if [[ ${UPDATE_DEADLINE} -lt ${CURRENT_DATE} && ${VER_CHECK} -eq "1" ]]; then
   # check if user has choosed to defer
   declare -a lines
   while IFS= read -r line; do
      lines+=("${line}")
   done < "${MACOS_UPGRADE_DEFERRAL}"
   USER_DEFERRAL_HOUR="${lines[0]}"
   USER_DEFERRAL_REMAINING="${lines[1]}"
   if [[ ${USER_DEFERRAL_HOUR} -lt ${CURRENT_HOUR} && ${USER_DEFERRAL_REMAINING} -gt 0 ]]; then
      send_upgrade_notification
   elif [[ ${USER_DEFERRAL_HOUR} -lt ${CURRENT_HOUR} && ${USER_DEFERRAL_REMAINING} -eq 0 ]]; then
      log_upgrade "No more user deferrals starting the upgrade process"
      if [[ -e ${IBM_NOTIFIER_SUPER} || -e ${IBM_NOTIFIER_APP} ]]; then
         if [[ ${OS_MAJOR_VERSION} -eq 14 ]]; then
            # initiate the download of the update and restart the device to complete the update
            /usr/local/bin/hubcli mdmcommand --osupdate --productversion 14.3.1 --installaction InstallASAP
         else
            # Treat here devices that are below Ventura
            /usr/local/bin/hubcli mdmcommand --osupdate --productversion 13.6.4 --installaction InstallASAP
         fi
      else
         send_password_notification
         if [[ ${OS_MAJOR_VERSION} -eq 14 ]]; then
            # initiate the download of the update and restart the device to complete the update
            echo "$PASS" | sudo -S /usr/local/bin/hubcli mdmcommand --osupdate --productversion 14.3.1 --installaction InstallASAP
         else
            # Treat here devices that are below Ventura
            echo "$PASS" | sudo -S /usr/local/bin/hubcli mdmcommand --osupdate --productversion 13.6.4 --installaction InstallASAP
         fi
      fi
   else
      # nothing to do, deferral not passed
      log_upgrade "Not passed the deferral set by the user - will retry on next sensor run"
   fi
else
   log_upgrade "System is runnig the laetst upgrade, nothig to do"
   exit 0
fi

exit 0
