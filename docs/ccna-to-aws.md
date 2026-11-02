# How this project maps to Cisco networking

This project was built while studying for the Cisco CCNA 200-301. Every AWS
building block here has a Cisco equivalent. This page is the translation guide.

> Exam tie-in: CCNA 200-301 v1.1 topic 6.6 asks you to *"recognize the
> capabilities of configuration management mechanisms such as Ansible and
> Terraform."* This repo is that topic, built hands-on.

---

## 1. Concept map

| AWS resource (this repo) | Cisco / CCNA equivalent | CCNA topic |
|---|---|---|
| VPC `10.0.0.0/16` | Your enterprise's private address block / routing domain | 1.6, 1.7 IPv4 addressing, private ranges |
| Subnet (`10.0.10.0/24`) | A VLAN + its SVI / an L3 segment | 1.6 subnetting, 2.1 VLANs |
| Availability Zone | A separate building or site with its own power and uplinks | 1.2 network topology architectures |
| Route table | The routing table (`show ip route`) | 3.1 routing table components |
| `local` route | Directly connected route (`C`) | 3.1 |
| `0.0.0.0/0 → IGW` | Static default route / gateway of last resort | 3.3 static routing |
| Internet Gateway | Edge router facing the ISP | 1.1 network components |
| NAT gateway | PAT: `ip nat inside source list X interface G0/0 overload` | 4.1 NAT |
| Data tier with no default route | A stub network with no gateway of last resort | 3.3 |
| Network ACL (stateless, per subnet) | Extended ACL on an interface | 5.6 ACLs |
| NACL rule number (`50`, `100`) | ACL sequence number | 5.6 |
| NACL `*` deny | Implicit `deny ip any any` | 5.6 |
| Security group (stateful, per ENI) | Stateful firewall / reflexive ACL / host firewall | 5.6, 5.1 security concepts |
| SG referencing another SG | Object-group based policy ("permit from WEB-SERVERS") | 5.6 |
| S3 prefix list | `ip prefix-list` / network object-group | 3.x, 5.6 |
| VPC Flow Logs | NetFlow + the `log` keyword on ACL entries | 4.x IP services, 5.x |
| Locked-down default SG | Shutting down unused switchports / native VLAN hygiene | 5.7 L2 security |
| Terraform code + CI | Configuration management / network automation | 6.1, 6.6 |
| Terraform state | A "source of truth" like NetBox / a running-config archive | 6.x |

---

## 2. Subnetting

All subnets are calculated by Terraform with `cidrsubnet(prefix, newbits, netnum)`:

```hcl
cidrsubnet("10.0.0.0/16", 8, 10)   # => "10.0.10.0/24"
#            ^ VPC block   ^ /16 + 8 bits = /24
#                             ^ 10th /24 inside the /16
```

| Subnet | CIDR | Network | Usable range | AWS-reserved |
|---|---|---|---|---|
| public-a | 10.0.0.0/24 | 10.0.0.0 | 10.0.0.4 to 10.0.0.254 | .0 .1 .2 .3 .255 |
| public-b | 10.0.1.0/24 | 10.0.1.0 | 10.0.1.4 to 10.0.1.254 | |
| app-a | 10.0.10.0/24 | 10.0.10.0 | 10.0.10.4 to 10.0.10.254 | |
| app-b | 10.0.11.0/24 | 10.0.11.0 | 10.0.11.4 to 10.0.11.254 | |
| data-a | 10.0.20.0/24 | 10.0.20.0 | 10.0.20.4 to 10.0.20.254 | |
| data-b | 10.0.21.0/24 | 10.0.21.0 | 10.0.21.4 to 10.0.21.254 | |

Difference from the CCNA: a /24 normally gives 2⁸ − 2 = 254 usable hosts.
AWS reserves 5 addresses per subnet: network, `.1` (VPC router), `.2` (DNS),
`.3` (reserved), and broadcast. That leaves 251 usable.

Summarization exercise: app-a + app-b (`10.0.10.0/24`, `10.0.11.0/24`) summarize
to `10.0.10.0/23` (wildcard `0.0.1.255`). The tier offsets (0 / 10 / 20) were chosen
so each tier's subnets stay contiguous and summarizable.

---

## 3. Direction gotcha: NACL "inbound" vs IOS "in"

An AWS NACL's inbound rules filter traffic entering the subnet. On a
Cisco router, that's an ACL applied `out` on the interface facing that
subnet (traffic leaves the router *into* the segment). The IOS translations
below are written as if applied on the router interface for each tier:

```
interface Vlan20                         ! data tier SVI
 ip access-group NACL-DATA-INBOUND out   ! AWS "inbound" = router "out"
 ip access-group NACL-DATA-OUTBOUND in   ! AWS "outbound" = router "in"
```

---

## 4. The full NACL policy written as IOS extended ACLs

This is the same policy defined in `modules/security/network_acls.tf`.
Sequence numbers match the AWS rule numbers. Assumes two AZs, no admin SSH,
and S3 access enabled.

### Public (web) tier
```
ip access-list extended NACL-PUBLIC-INBOUND
 100 permit tcp any any eq 443                         ! HTTPS from the internet
 200 permit tcp any any range 1024 65535               ! return traffic (stateless!)
 ! implicit: deny ip any any

ip access-list extended NACL-PUBLIC-OUTBOUND
 100 permit tcp any any range 1024 65535               ! replies to HTTPS clients
 110 permit tcp any 10.0.10.0 0.0.0.255 eq 8080        ! to app-a
 111 permit tcp any 10.0.11.0 0.0.0.255 eq 8080        ! to app-b
 200 permit tcp any any eq 443                         ! OS/package updates
```

### App tier
```
ip access-list extended NACL-APP-INBOUND
 100 permit tcp 10.0.0.0 0.0.0.255 any eq 8080         ! from web-a
 101 permit tcp 10.0.1.0 0.0.0.255 any eq 8080         ! from web-b
 200 permit tcp 10.0.20.0 0.0.0.255 any range 1024 65535 ! DB replies
 201 permit tcp 10.0.21.0 0.0.0.255 any range 1024 65535
 300 permit tcp any any range 1024 65535               ! S3 replies

ip access-list extended NACL-APP-OUTBOUND
 100 permit tcp any 10.0.0.0 0.0.0.255 range 1024 65535 ! replies to web
 101 permit tcp any 10.0.1.0 0.0.0.255 range 1024 65535
 200 permit tcp any 10.0.20.0 0.0.0.255 eq 5432        ! to PostgreSQL
 201 permit tcp any 10.0.21.0 0.0.0.255 eq 5432
 300 permit tcp any any eq 443                         ! to S3 endpoint
```

### Data tier
```
ip access-list extended NACL-DATA-INBOUND
 50  deny   ip  10.0.0.0 0.0.0.255 any                 ! web tier: never
 51  deny   ip  10.0.1.0 0.0.0.255 any
 100 permit tcp 10.0.10.0 0.0.0.255 any eq 5432        ! app tier: DB only
 101 permit tcp 10.0.11.0 0.0.0.255 any eq 5432

ip access-list extended NACL-DATA-OUTBOUND
 100 permit tcp any 10.0.10.0 0.0.0.255 range 1024 65535 ! replies to app only
 101 permit tcp any 10.0.11.0 0.0.0.255 range 1024 65535
```

Why the explicit deny at 50? The implicit deny would already block the web
tier. The explicit entry documents intent, survives a future permit being
added carelessly, and, with flow logs, makes violations show up clearly as
REJECT records. It's the same reason you'd add `deny ip any any log` at the
end of an IOS ACL.

---

## 5. Stateless vs stateful: the core security idea

| | Network ACL | Security group |
|---|---|---|
| State | Stateless: return traffic needs its own rule | Stateful: return traffic allowed automatically |
| Cisco analogy | Standard/extended ACL | Reflexive ACL, CBAC/ZBF, ASA |
| Applies to | Every resource in the subnet | Only ENIs it's attached to |
| Rule order | Numbered, first match wins | All rules evaluated, permit-only |
| Deny rules | Yes | No (allow-list only) |
| Can reference | CIDRs only | CIDRs, prefix lists, other security groups |

The `range 1024 65535` lines exist only because NACLs are stateless.
A client's source port is ephemeral (random high port), so the reply must be
allowed back to it. In IOS you might use `permit tcp any any established`
(matches ACK/RST). NACLs have no such keyword, so the ephemeral range is used.
