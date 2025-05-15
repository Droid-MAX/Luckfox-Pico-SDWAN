#!/bin/bash
PATH=/usr/local/sbin:/usr/sbin:/sbin:$PATH

if [ $EUID != 0 ]; then
  sudo "$0" "$@"
  exit $?
fi

inbond_iface="usb0"
outbond_iface="eth0"

check_inbond_addr(){
	inbond_cidr_addr=$(ip -4 -br addr show $inbond_iface | tr -s ' ' | cut -d' ' -f3)
	if [ -z "$inbond_cidr_addr" ]; then
		echo "[!] could not get ip address for interface $inbond_iface"
		exit 1
	fi
}

check_ipv4_forward(){
	if [ "$(cat /proc/sys/net/ipv4/ip_forward)" -eq "1" ]; then
		echo 1
	else
		echo 0
	fi
}

enable_ipv4_forward(){
	pre_checking_forward=$(check_ipv4_forward)
	if [ "$pre_checking_forward" -eq 0 ]; then
		echo "[+] enabling ipv4 forward..."
		echo 1 > /proc/sys/net/ipv4/ip_forward
	fi
}

check_iptables_rule_exists(){
	local forward_rule_1=$(iptables -C FORWARD -i $inbond_iface -o $outbond_iface -j ACCEPT 2>/dev/null; echo $?)
	local forward_rule_2=$(iptables -C FORWARD -i $outbond_iface -o $inbond_iface -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; echo $?)
	local nat_rule=$(iptables -t nat -C POSTROUTING -s $inbond_cidr_addr -o $outbond_iface -j MASQUERADE 2>/dev/null; echo $?)
	if [ "$forward_rule_1" -eq 0 ] && [ "$forward_rule_2" -eq 0 ] && [ "$nat_rule" -eq 0 ]; then
		echo 0
	else
		echo 1
	fi
}

add_iptables_rules(){
	check_inbond_addr
	pre_existing_rule=$(check_iptables_rule_exists)
	if [ "$pre_existing_rule" -eq 1 ]; then
		iptables -A FORWARD -i $inbond_iface -o $outbond_iface -j ACCEPT
		iptables -A FORWARD -i $outbond_iface -o $inbond_iface -m state --state RELATED,ESTABLISHED -j ACCEPT
		iptables -t nat -A POSTROUTING -s $inbond_cidr_addr -o $outbond_iface -j MASQUERADE
	else
		echo "[!] iptables rules already exists on system"
		exit 1
	fi
}

remove_iptables_rules(){
	check_inbond_addr
	pre_existing_rule=$(check_iptables_rule_exists)
	if [ "$pre_existing_rule" -eq 0 ]; then
		iptables -D FORWARD -i $inbond_iface -o $outbond_iface -j ACCEPT
		iptables -D FORWARD -i $outbond_iface -o $inbond_iface -m state --state RELATED,ESTABLISHED -j ACCEPT
		iptables -t nat -D POSTROUTING -s $inbond_cidr_addr -o $outbond_iface -j MASQUERADE
	else
		echo "[!] iptables rules already removed from system"
		exit 1
	fi
}

do_enable(){
	enable_ipv4_forward
	add_iptables_rules
	echo "[+] nat forward is enabled"
	echo "[+] inbond interface: $inbond_iface"
	echo "[+] outbond interface: $outbond_iface"
	exit 0
}

do_disable(){
	remove_iptables_rules
	echo "[+] nat forward is disabled"
	echo "[+] inbond interface: $inbond_iface"
	echo "[+] outbond interface: $outbond_iface"
	exit 0
}

usage(){
    echo "Usage: $0 {enable|disable} [-i/--inbond <interface>] [-o/--outbond <interface>]"
    echo "Options:"
    echo "  enable/disable	Enable or disable forwarding (required)"
    echo "  -i, --inbond <iface>	Specify inbound interface (default: usb0)"
    echo "  -o, --outbond <iface>	Specify outbound interface (default: eth0)"
    echo "  -h, --help		Get help for commands"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        enable|disable)
            action=$1
            shift
            ;;
        -i|--inbond)
            inbond_iface=$2
            shift 2
            ;;
        -o|--outbond)
            outbond_iface=$2
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

if [ -z "$action" ]; then
    usage
fi

case "$action" in
    enable)
        do_enable
        ;;
    disable)
        do_disable
        ;;
    *)
        usage
        ;;
esac
