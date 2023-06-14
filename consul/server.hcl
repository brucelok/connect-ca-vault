server      = true
bootstrap   = true
datacenter = "dc1"
client_addr = "0.0.0.0"
data_dir    = "/consul/data"

ui_config {
  enabled = true
}

log_level = "debug"

## Service mesh CA configuration
connect {
  enabled     = true
  ca_provider = "vault"
  ca_config {
    address               = "http://10.0.0.2:8200"
    token                 = "hvs.CAESIEQ-c3kFvpIMGeYrdOqY16ZETEeSs1wT3U04vhdwFTJgGh4KHGh2cy5ia3BRYUwzVm51S3IwVDZRTnk0TU52Nlg"
    root_pki_path         = "connect_root"
    intermediate_pki_path = "connect_inter"
    leaf_cert_ttl         = "72h"
    rotation_period       = "2160h"
    intermediate_cert_ttl = "8760h"
    private_key_type      = "rsa"
    private_key_bits      = 2048
  }
}
