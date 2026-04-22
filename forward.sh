#!/bin/bash
PATH=/usr/local/sbin:/usr/sbin:/sbin:$PATH

if [ $EUID != 0 ]; then
  sudo "$0" "$@"
  exit $?
fi

inbond_iface="usb0"
outbond_iface="eth0"

check_iface_exists() {
  ip link show "$1" >/dev/null 2>&1 || {
    echo "[!] Interface $1 does not exist"
    return 1
  }
}

check_inbond_addr(){
	inbond_subnet=$(ip -4 -br addr show $inbond_iface | tr -s ' ' | cut -d' ' -f3)
	if [ -z "$inbond_subnet" ]; then
		echo "[!] Could not get IPv4 address for interface $inbond_iface"
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
	if [ "$(check_ipv4_forward)" -eq 0 ]; then
		echo "[+] Enabling IPv4 forwarding..."
		echo 1 > /proc/sys/net/ipv4/ip_forward
	fi
}

add_iptables_rules(){
	check_inbond_addr
	check_iface_exists "$outbond_iface" || exit 1

	if ! iptables -C FORWARD -i "$inbond_iface" -o "$outbond_iface" -j ACCEPT 2>/dev/null; then
		echo "[+] Adding IPv4 forwarding rule: $inbond_iface -> $outbond_iface"
		iptables -A FORWARD -i "$inbond_iface" -o "$outbond_iface" -j ACCEPT
	else
		echo "[!] Forward rule already exists: $inbond_iface -> $outbond_iface"
	fi

	if ! iptables -C FORWARD -i "$outbond_iface" -o "$inbond_iface" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; then
		echo "[+] Adding IPv4 forwarding rule: $outbond_iface -> $inbond_iface (RELATED,ESTABLISHED)"
		iptables -A FORWARD -i "$outbond_iface" -o "$inbond_iface" -m state --state RELATED,ESTABLISHED -j ACCEPT
	else
		echo "[!] Forward rule already exists: $outbond_iface -> $inbond_iface (RELATED,ESTABLISHED)"
	fi

	if ! iptables -t nat -C POSTROUTING -s "$inbond_subnet" -o "$outbond_iface" -j MASQUERADE 2>/dev/null; then
		echo "[+] Adding IPv4 MASQUERADE rule for $inbond_subnet on $outbond_iface"
		iptables -t nat -A POSTROUTING -s "$inbond_subnet" -o "$outbond_iface" -j MASQUERADE
	else
		echo "[!] MASQUERADE rule already exists for $inbond_subnet"
	fi
}

remove_iptables_rules(){
	check_inbond_addr

	if iptables -C FORWARD -i "$inbond_iface" -o "$outbond_iface" -j ACCEPT 2>/dev/null; then
		echo "[+] Deleting IPv4 forwarding rule: $inbond_iface -> $outbond_iface"
		iptables -D FORWARD -i "$inbond_iface" -o "$outbond_iface" -j ACCEPT
	else
		echo "[!] Forward rule not present: $inbond_iface -> $outbond_iface"
	fi

	if iptables -C FORWARD -i "$outbond_iface" -o "$inbond_iface" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; then
		echo "[+] Deleting IPv4 forwarding rule: $outbond_iface -> $inbond_iface (RELATED,ESTABLISHED)"
		iptables -D FORWARD -i "$outbond_iface" -o "$inbond_iface" -m state --state RELATED,ESTABLISHED -j ACCEPT
	else
		echo "[!] Forward rule not present: $outbond_iface -> $inbond_iface (RELATED,ESTABLISHED)"
	fi

	if iptables -t nat -C POSTROUTING -s "$inbond_subnet" -o "$outbond_iface" -j MASQUERADE 2>/dev/null; then
		echo "[+] Deleting IPv4 MASQUERADE rule for $inbond_subnet"
		iptables -t nat -D POSTROUTING -s "$inbond_subnet" -o "$outbond_iface" -j MASQUERADE
	else
		echo "[!] MASQUERADE rule not present for $inbond_subnet"
	fi
}

do_enable(){
	enable_ipv4_forward
	add_iptables_rules
	echo "[+] IPv4 NAT forwarding enabled"
	echo "    Inbound interface : $inbond_iface"
	echo "    Outbound interface: $outbond_iface"
	exit 0
}

do_disable(){
	remove_iptables_rules
	echo "[+] IPv4 NAT forwarding disabled"
	exit 0
}

usage(){
    echo "Usage: $0 {enable|disable} [-i/--inbond <interface>] [-o/--outbond <interface>]"
    echo "Options:"
    echo "  enable/disable        Enable or disable forwarding (required)"
    echo "  -i, --inbond <iface>  Specify inbound interface (default: usb0)"
    echo "  -o, --outbond <iface> Specify outbound interface (default: eth0)"
    echo "  -h, --help            Show this help"
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
            echo "[!] Unknown option: $1"
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