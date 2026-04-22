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

check_ipv6_forward() {
  [ "$(cat /proc/sys/net/ipv6/conf/all/forwarding)" -eq "1" ] && echo 1 || echo 0
}

enable_ipv6_forward() {
  if [ "$(check_ipv6_forward)" -eq 0 ]; then
    echo "[+] Enabling IPv6 forwarding..."
    echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
  fi
}

add_ip6tables_rules() {
  check_iface_exists "$inbond_iface" || exit 1
  check_iface_exists "$outbond_iface" || exit 1

  if ! ip6tables -C FORWARD -i "$inbond_iface" -o "$outbond_iface" -j ACCEPT 2>/dev/null; then
    echo "[+] Adding IPv6 forwarding rule: $inbond_iface -> $outbond_iface"
    ip6tables -A FORWARD -i "$inbond_iface" -o "$outbond_iface" -j ACCEPT
  else
    echo "[!] Forward rule already exists: $inbond_iface -> $outbond_iface"
  fi

  if ! ip6tables -C FORWARD -i "$outbond_iface" -o "$inbond_iface" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; then
    echo "[+] Adding IPv6 forwarding rule: $outbond_iface -> $inbond_iface (RELATED,ESTABLISHED)"
    ip6tables -A FORWARD -i "$outbond_iface" -o "$inbond_iface" -m state --state RELATED,ESTABLISHED -j ACCEPT
  else
    echo "[!] Forward rule already exists: $outbond_iface -> $inbond_iface (RELATED,ESTABLISHED)"
  fi

  if ! ip6tables -t nat -C POSTROUTING -o "$outbond_iface" -j MASQUERADE 2>/dev/null; then
    echo "[+] Adding IPv6 MASQUERADE rule on $outbond_iface"
    ip6tables -t nat -A POSTROUTING -o "$outbond_iface" -j MASQUERADE
  else
    echo "[!] MASQUERADE rule already exists on $outbond_iface"
  fi
}

remove_ip6tables_rules() {
  if ip6tables -C FORWARD -i "$inbond_iface" -o "$outbond_iface" -j ACCEPT 2>/dev/null; then
    echo "[+] Deleting IPv6 forwarding rule: $inbond_iface -> $outbond_iface"
    ip6tables -D FORWARD -i "$inbond_iface" -o "$outbond_iface" -j ACCEPT
  else
    echo "[!] Forward rule not present: $inbond_iface -> $outbond_iface"
  fi

  if ip6tables -C FORWARD -i "$outbond_iface" -o "$inbond_iface" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; then
    echo "[+] Deleting IPv6 forwarding rule: $outbond_iface -> $inbond_iface (RELATED,ESTABLISHED)"
    ip6tables -D FORWARD -i "$outbond_iface" -o "$inbond_iface" -m state --state RELATED,ESTABLISHED -j ACCEPT
  else
    echo "[!] Forward rule not present: $outbond_iface -> $inbond_iface (RELATED,ESTABLISHED)"
  fi

  if ip6tables -t nat -C POSTROUTING -o "$outbond_iface" -j MASQUERADE 2>/dev/null; then
    echo "[+] Deleting IPv6 MASQUERADE rule on $outbond_iface"
    ip6tables -t nat -D POSTROUTING -o "$outbond_iface" -j MASQUERADE
  else
    echo "[!] MASQUERADE rule not present on $outbond_iface"
  fi
}

do_enable() {
  enable_ipv6_forward
  add_ip6tables_rules
  echo "[+] IPv6 NAT forwarding enabled"
  echo "    Inbound interface : $inbond_iface"
  echo "    Outbound interface: $outbond_iface"
  exit 0
}

do_disable() {
  remove_ip6tables_rules
  echo "[+] IPv6 NAT forwarding disabled"
  exit 0
}

usage() {
    echo "Usage: $0 {enable|disable} [-i/--inbond <interface>] [-o/--outbond <interface>]"
    echo "Options:"
    echo "  enable/disable        Enable or disable forwarding (required)"
    echo "  -i, --inbond <iface>  Specify inbound interface (default: usb0)"
    echo "  -o, --outbond <iface> Specify outbound interface (default: eth0)"
    echo "  -h, --help            Show this help"
    exit 1
}

action=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    enable|disable)
      action="$1"
      shift
      ;;
    -i|--inbond)
      inbond_iface="$2"
      shift 2
      ;;
    -o|--outbond)
      outbond_iface="$2"
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