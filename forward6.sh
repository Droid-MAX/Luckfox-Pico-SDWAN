#!/bin/bash
PATH=/usr/local/sbin:/usr/sbin:/sbin:$PATH

if [ $EUID != 0 ]; then
  sudo "$0" "$@"
  exit $?
fi

inbond_iface="usb0"
outbond_iface="autowg"
peer_subnet=""

check_iface_exists() {
  ip link show "$1" >/dev/null 2>&1 || {
    echo "[!] Interface $1 does not exist"
    return 1
  }
}

get_peer_subnet() {
  local iface="$1"
  local subnet

  subnet=$(wg show "$iface" 2>/dev/null | awk '/allowed ips:/ {
      for(i=3;i<=NF;i++) if($i ~ /^[0-9a-f:]+:\/[0-9]+$/ && $i !~ /\/128$/) {print $i; exit}
  }')

  if [ -n "$subnet" ]; then
    peer_subnet="$subnet"
    echo "[*] Subnet obtained from peer config: $peer_subnet"
    return 0
  fi

  local addr
  addr=$(ip -6 -br addr show "$iface" 2>/dev/null | awk '{for(i=2;i<=NF;i++) if($i !~ /^fe80:/) {sub(/\/.*/,"",$i); print $i; exit}}')
  if [ -n "$addr" ]; then
    peer_subnet="${addr}/64"
    echo "[*] Subnet inferred from interface address: $peer_subnet"
    return 0
  fi

  echo "[!] Unable to determine peer subnet"
  return 1
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

check_ipv6_route_exists() {
  ip -6 route show "$peer_subnet" | grep -q "dev $outbond_iface" && echo 0 || echo 1
}

add_ipv6_route() {
  if [ "$(check_ipv6_route_exists)" -eq 1 ]; then
    echo "[+] Adding IPv6 route $peer_subnet dev $outbond_iface"
    ip -6 route add "$peer_subnet" dev "$outbond_iface" || {
      echo "[!] Failed to add IPv6 route"
      exit 1
    }
  else
    echo "[!] IPv6 route already exists"
  fi
}

remove_ipv6_route() {
  if [ "$(check_ipv6_route_exists)" -eq 0 ]; then
    echo "[+] Deleting IPv6 route $peer_subnet dev $outbond_iface"
    ip -6 route del "$peer_subnet" dev "$outbond_iface"
  else
    echo "[!] IPv6 route does not exist"
  fi
}

do_enable() {
  if [ -z "$peer_subnet" ]; then
    get_peer_subnet "$outbond_iface" || exit 1
  fi

  enable_ipv6_forward
  add_ip6tables_rules
  add_ipv6_route
  echo "[+] IPv6 NAT forwarding enabled"
  echo "    Inbound interface : $inbond_iface"
  echo "    Outbound interface: $outbond_iface"
  echo "    Peer subnet       : $peer_subnet"
  exit 0
}

do_disable() {
  if [ -z "$peer_subnet" ]; then
    get_peer_subnet "$outbond_iface" || {
      echo "[!] Unable to obtain subnet automatically, skipping route removal"
      peer_subnet=""
    }
  fi

  remove_ip6tables_rules
  if [ -n "$peer_subnet" ]; then
    remove_ipv6_route
  fi
  echo "[+] IPv6 NAT forwarding disabled"
  exit 0
}

usage() {
    echo "Usage: $0 {enable|disable} [-i/--inbond <interface>] [-o/--outbond <interface>] [-s/--peer-subnet <cidr>]"
    echo "Options:"
    echo "  enable/disable           Enable or disable forwarding (required)"
    echo "  -i, --inbond <iface>     Specify inbound interface (default: usb0)"
    echo "  -o, --outbond <iface>    Specify outbound interface (default: autowg)"
    echo "  -s, --peer-subnet <cidr> Manually specify peer IPv6 subnet (e.g., fde3:25fb:7f6c:1::/64)"
    echo "  -h, --help               Show this help"
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
    -s|--peer-subnet)
      peer_subnet="$2"
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