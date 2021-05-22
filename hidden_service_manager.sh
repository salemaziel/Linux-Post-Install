#!/bin/bash
# https://github.com/complexorganizations/hidden-service-manager

# https://community.torproject.org/relay/setup/

function hidden_service_manager() {

# Require script to be run as root
function super-user-check() {
  if [ "${EUID}" -ne 0 ]; then
    echo "You need to run this script as super user."
    exit
  fi
}

# Check for root
super-user-check

# Detect Operating System
function dist-check() {
  if [ -e /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    DISTRO=${ID}
  fi
}

# Check Operating System
dist-check

# Pre-Checks system requirements
function installing-system-requirements() {
  if { [ "${DISTRO}" == "ubuntu" ] || [ "${DISTRO}" == "debian" ] || [ "${DISTRO}" == "raspbian" ] || [ "${DISTRO}" == "pop" ] || [ "${DISTRO}" == "kali" ] || [ "${DISTRO}" == "fedora" ] || [ "${DISTRO}" == "centos" ] || [ "${DISTRO}" == "rhel" ] || [ "${DISTRO}" == "arch" ] || [ "${DISTRO}" == "manjaro" ] || [ "${DISTRO}" == "alpine" ]; }; then
    if { [ ! -x "$(command -v curl)" ] || [ ! -x "$(command -v iptables)" ] || [ ! -x "$(command -v bc)" ] || [ ! -x "$(command -v jq)" ] || [ ! -x "$(command -v sed)" ] || [ ! -x "$(command -v zip)" ] || [ ! -x "$(command -v unzip)" ] || [ ! -x "$(command -v grep)" ] || [ ! -x "$(command -v awk)" ] || [ ! -x "$(command -v ip)" ]; }; then
      if { [ "${DISTRO}" == "ubuntu" ] || [ "${DISTRO}" == "debian" ] || [ "${DISTRO}" == "raspbian" ] || [ "${DISTRO}" == "pop" ] || [ "${DISTRO}" == "kali" ]; }; then
        apt-get update && apt-get install iptables curl coreutils bc jq sed e2fsprogs zip unzip grep gawk iproute2 -y
      elif { [ "${DISTRO}" == "fedora" ] || [ "${DISTRO}" == "centos" ] || [ "${DISTRO}" == "rhel" ]; }; then
        yum update -y && yum install epel-release iptables curl coreutils bc jq sed e2fsprogs zip unzip grep gawk iproute2 -y
      elif { [ "${DISTRO}" == "arch" ] || [ "${DISTRO}" == "manjaro" ]; }; then
        pacman -Syu --noconfirm --needed iptables curl bc jq sed zip unzip grep gawk iproute2
      elif [ "${DISTRO}" == "alpine" ]; then
        apk update && apk add iptables curl bc jq sed zip unzip grep gawk iproute2
      fi
    fi
  else
    echo "Error: ${DISTRO} not supported."
    exit
  fi
}

# Run the function and check for requirements
installing-system-requirements

# Global variables
TOR_PATH="/etc/tor"
TOR_TORRC="${TOR_PATH}/torrc"
HIDDEN_SERVICE_MANAGER="${TOR_PATH}/hidden-service-manager"
TOR_HIDDEN_SERVICE="${TOR_PATH}/hidden-service"
TOR_RELAY_SERVICE="${TOR_PATH}/relay-service"
TOR_BRIDGE_SERVICE="${TOR_PATH}/bridge-service"
TOR_EXIT_SERVICE="${TOR_PATH}/exit-service"
TOR_TORRC_BACKUP="/var/backups/hidden-service-manager.zip"
HIDDEN_SERVICE_MANAGER_UPDATE="https://raw.githubusercontent.com/complexorganizations/hidden-service-manager/main/hidden-service-manager.sh"
CONTACT_INFO_NAME="$(openssl rand -hex 9)"
CONTACT_INFO_EMAIL="$(openssl rand -hex 25)"

if [ ! -f "${HIDDEN_SERVICE_MANAGER}" ]; then

  # ask the user what to install
  function choose-hidden-service() {
    if [ ! -f "${HIDDEN_SERVICE_MANAGER}" ]; then
      echo "What would you like to install?"
      echo "  1) TOR (Recommended)"
      until [[ "${HIDDEN_SERVICE_CHOICE_SETTINGS}" =~ ^[1-1]$ ]]; do
        read -rp "Installer Choice [1-4]: " -e -i 1 HIDDEN_SERVICE_CHOICE_SETTINGS
      done
      case ${HIDDEN_SERVICE_CHOICE_SETTINGS} in
      1)
        if [ -d "${TOR_PATH}" ]; then
          rm -rf ${TOR_PATH}
        fi
        mkdir -p ${TOR_PATH}
        echo "TOR: true" >>${HIDDEN_SERVICE_MANAGER}
        ;;
      esac
    fi
  }

  # ask the user what to install
  choose-hidden-service

  # ask the user what to install
  function what-to-install() {
    if [ -f "${HIDDEN_SERVICE_MANAGER}" ]; then
      echo "What would you like to install?"
      echo "  1) Hidden Service (Recommended)"
      echo "  2) Relay"
      echo "  3) Bridge"
      echo "  4) Exit Node (Advanced)"
      until [[ "${INSTALLER_COICE_SETTINGS}" =~ ^[1-4]$ ]]; do
        read -rp "Installer Choice [1-4]: " -e -i 1 INSTALLER_COICE_SETTINGS
      done
      case ${INSTALLER_COICE_SETTINGS} in
      1)
        echo "Hidden: true" >>${TOR_HIDDEN_SERVICE}
        ;;
      2)
        echo "Relay: true" >>${TOR_RELAY_SERVICE}
        ;;
      3)
        echo "Bridge: true" >>${TOR_BRIDGE_SERVICE}
        ;;
      4)
        echo "Exit: true" >>${TOR_EXIT_SERVICE}
        ;;
      esac
    fi
  }

  # ask the user what to install
  what-to-install

  # Question 1: Determine host port
  function set-port() {
    if { [ -f "${TOR_RELAY_SERVICE}" ] || [ -f "${TOR_EXIT_SERVICE}" ]; }; then
      echo "Do u want to use the recommened ports?"
      echo "   1) Yes (Recommended)"
      echo "   2) Custom (Advanced)"
      until [[ "${PORT_CHOICE_SETTINGS}" =~ ^[1-2]$ ]]; do
        read -rp "Port choice [1-2]: " -e -i 1 PORT_CHOICE_SETTINGS
      done
      case ${PORT_CHOICE_SETTINGS} in
      1)
        OR_SERVER_PORT="9001"
        CON_SERVER_PORT="9051"
        OBSF_SERVER_PORT="8042"
        ;;
      2)
        read -rp "Custom OR Port" -e -i "9001" OR_SERVER_PORT
        read -rp "Custom CON Port" -e -i "9051" CON_SERVER_PORT
        read -rp "Custom OSBF Port" -e -i "8042" OBSF_SERVER_PORT
        ;;
      esac
    fi
  }

  # Set the port number
  set-port

  # Install Tor
  function install-tor() {
    if [ ! -x "$(command -v tor)" ]; then
      if { [ -f "${TOR_HIDDEN_SERVICE}" ] || [ -f "${TOR_RELAY_SERVICE}" ] || [ -f "${TOR_BRIDGE_SERVICE}" ] || [ -f "${TOR_EXIT_SERVICE}" ]; }; then
        if { [ "${DISTRO}" == "ubuntu" ] || [ "${DISTRO}" == "debian" ] || [ "${DISTRO}" == "raspbian" ] || [ "${DISTRO}" == "pop" ] || [ "${DISTRO}" == "kali" ]; }; then
          apt-get update
          apt-get install ntpdate tor nyx obfs4proxy -y
        elif { [ "${DISTRO}" == "fedora" ] || [ "${DISTRO}" == "centos" ] || [ "${DISTRO}" == "rhel" ]; }; then
          yum update
          yun install ntp tor nyx -y
        elif { [ "${DISTRO}" == "arch" ] || [ "${DISTRO}" == "manjaro" ]; }; then
          pacman -Syu
          pacman -Syu --noconfirm --needed tor ntp
        elif [ "${DISTRO}" == "alpine" ]; then
          apk update
          apk add tor ntp
        fi
      fi
    fi
  }

  # Install Tor
  install-tor

  function install-unbound() {
    if [ ! -x "$(command -v unbound)" ]; then
        if { [ "${DISTRO}" == "ubuntu" ] || [ "${DISTRO}" == "debian" ] || [ "${DISTRO}" == "raspbian" ] || [ "${DISTRO}" == "pop" ] || [ "${DISTRO}" == "kali" ]; }; then
          apt-get update
          apt-get install unbound -y
        elif { [ "${DISTRO}" == "fedora" ] || [ "${DISTRO}" == "centos" ] || [ "${DISTRO}" == "rhel" ]; }; then
          yum update
          yun install unbound -y
        elif { [ "${DISTRO}" == "arch" ] || [ "${DISTRO}" == "manjaro" ]; }; then
          pacman -Syu
          pacman -Syu --noconfirm --needed unbound
        elif [ "${DISTRO}" == "alpine" ]; then
          apk update
          apk add unbound
      fi
    fi
  }

  install-unbound

  function configure-ntp() {
    if [ -x "$(command -v ntp)" ]; then
        ntpdate pool.ntp.org
    fi
  }

  configure-ntp

  function bridge-config() {
    if [ -f "${TOR_BRIDGE_SERVICE}" ]; then
      echo "BridgeRelay 1
ORPort ${OR_SERVER_PORT}
ServerTransportPlugin obfs4 exec /usr/bin/obfs4proxy
ServerTransportListenAddr obfs4 0.0.0.0:${OBSF_SERVER_PORT}
ExtORPort auto
Nickname ${CONTACT_INFO_NAME}
ContactInfo ${CONTACT_INFO_EMAIL}
CookieAuthentication 1
ControlPort ${CON_SERVER_PORT}" >>${TOR_TORRC}
    fi
  }

  bridge-config

  function relay-config() {
    if [ -f "${TOR_RELAY_SERVICE}" ]; then
      echo "Nickname ${CONTACT_INFO_NAME}
ORPort ${OR_SERVER_PORT}
ExitRelay 0
SocksPort 0
ControlSocket 0
ControlPort ${CON_SERVER_PORT}
CookieAuthentication 1
ContactInfo ${CONTACT_INFO_EMAIL}" >>${TOR_TORRC}
    fi
  }

  relay-config

  function exit-config() {
    if [ -f "${TOR_HIDDEN_SERVICE}" ]; then
      echo "SocksPort 0
ORPort ${OR_SERVER_PORT}
Nickname ${CONTACT_INFO_NAME}
ContactInfo ${CONTACT_INFO_EMAIL}
DirPortFrontPage /etc/tor/tor-exit-notice.html
ExitPolicy accept *:443       # HTTPS
ExitPolicy reject *:*
IPv6Exit 1
ControlPort ${CON_SERVER_PORT}
CookieAuthentication 1" >>${TOR_TORRC}
      echo "<!DOCTYPE html>
<html>
   <head>
      <title>Tor Router</title>
   </head>
   <body>
      <h1>This is a tor router</h1>
   </body>
</html>" >>/etc/tor/tor-exit-notice.html
    fi
  }

  exit-config
  
  function unbound-config() {
      chattr -i /etc/resolv.conf
      sed -i "s|nameserver|#nameserver|" /etc/resolv.conf
      sed -i "s|search|#search|" /etc/resolv.conf
      echo "nameserver 127.0.0.1" >>/etc/resolv.conf
      chattr +i /etc/resolv.conf
  }

  function restart-service() {
    if pgrep systemd-journal; then
      # Tor
      systemctl enable tor
      systemctl restart tor
      # NTP
      systemctl enable ntp
      systemctl restart ntp
      # fail2ban
      systemctl enable fail2ban
      systemctl restart fail2ban
      # Unbound
        systemctl enable unbound
        systemctl restart unbound
    else
      # Tor
      service tor enable
      service tor restart
      # NTP
      service ntp enable
      service ntp restart
      # Fail2ban
      service fail2ban enable
      service fail2ban restart
      # Unbound
        service unbound enable
        service unbound restart
    fi
  }

  restart-service

else

  function after-install-questions() {
    if { [ -f "${TOR_HIDDEN_SERVICE}" ] || [ -f "${TOR_RELAY_SERVICE}" ] || [ -f "${TOR_BRIDGE_SERVICE}" ] || [ -f "${TOR_EXIT_SERVICE}" ]; }; then
      echo "What do you want to do?"
      echo "   1) Update the script"
      echo "   2) Uninstall"
      echo "   3) Reinstall"
      echo "   4) Backup"
      echo "   5) Restore"
      until [[ "${HIDDEN_SERVICE_MANAGER_OPTIONS}" =~ ^[0-9]+$ ]] && [ "${HIDDEN_SERVICE_MANAGER_OPTIONS}" -ge 1 ] && [ "${HIDDEN_SERVICE_MANAGER_OPTIONS}" -le 5 ]; do
        read -rp "Select an Option [1-5]: " -e -i 1 HIDDEN_SERVICE_MANAGER_OPTIONS
      done
      case ${HIDDEN_SERVICE_MANAGER_OPTIONS} in
      1)
        CURRENT_FILE_PATH="$(realpath "$0")"
        if [ -f "${CURRENT_FILE_PATH}" ]; then
          curl -o "${CURRENT_FILE_PATH}" ${HIDDEN_SERVICE_MANAGER_UPDATE}
          chmod +x "${CURRENT_FILE_PATH}" || exit
        fi
        ;;
      2)
        if [ -f "${HIDDEN_SERVICE_MANAGER}" ]; then
          rm -rf ${TOR_PATH}
          if { [ "${DISTRO}" == "centos" ] || [ "${DISTRO}" == "rhel" ]; }; then
            yum remove ntpdate tor nyx -y
          elif { [ "${DISTRO}" == "debian" ] || [ "${DISTRO}" == "kali" ] || [ "${DISTRO}" == "pop" ] || [ "${DISTRO}" == "ubuntu" ] || [ "${DISTRO}" == "raspbian" ]; }; then
            apt-get remove --purge ntpdate tor nyx -y
          elif { [ "${DISTRO}" == "arch" ] || [ "${DISTRO}" == "manjaro" ]; }; then
            pacman -Rs ntpdate tor nyx -y
          elif [ "${DISTRO}" == "fedora" ]; then
            dnf remove ntpdate tor nyx -y
          elif [ "${DISTRO}" == "alpine" ]; then
            apk del tor
          fi
        fi
        ;;
      3)
        if { [ "${DISTRO}" == "ubuntu" ] || [ "${DISTRO}" == "debian" ] || [ "${DISTRO}" == "raspbian" ] || [ "${DISTRO}" == "pop" ] || [ "${DISTRO}" == "kali" ]; }; then
          dpkg-reconfigure tor
          modprobe tor
          systemctl restart tor
        elif { [ "${DISTRO}" == "fedora" ] || [ "${DISTRO}" == "centos" ] || [ "${DISTRO}" == "rhel" ]; }; then
          yum reinstall tor -y
          service torC restart
        elif { [ "${DISTRO}" == "arch" ] || [ "${DISTRO}" == "manjaro" ]; }; then
          pacman -Rs --noconfirm tor
          service tor restart
        elif [ "${DISTRO}" == "alpine" ]; then
          apk fix tor
        fi
        ;;
      4)
        if [ -x "$(command -v tor)" ]; then
          if [ -d "${TOR_TORRC}" ]; then
            rm -f ${TOR_TORRC_BACKUP}
            zip -r -j ${TOR_TORRC_BACKUP} ${TOR_TORRC} ${HIDDEN_SERVICE_MANAGER} ${TOR_HIDDEN_SERVICE} ${TOR_RELAY_SERVICE} ${TOR_BRIDGE_SERVICE} ${TOR_EXIT_SERVICE}
          else
            exit
          fi
        fi
        ;;
      5)
        if [ -x "$(command -v tor)" ]; then
          if [ -f "${TOR_TORRC_BACKUP}" ]; then
            rm -rf ${TOR_TORRC}
            unzip ${TOR_TORRC} -d ${TOR_PATH}
          else
            exit
          fi
        fi
        ;;
      esac
    fi
  }

  after-install-questions

fi

}