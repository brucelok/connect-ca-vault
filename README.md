# Objective

To understand how Vault CA provider work for Consul
https://learn.hashicorp.com/tutorials/consul/vault-pki-consul-connect-ca?in=consul/vault-secure

# Steps

1. Install Vault

We are running Vault in DEV mode, take note of the root token in 

```
docker compose up vault -d
docker logs vault | grep "Root Token"
```

2. Create Vault policy for Consul PKI paths

```
docker cp vault-policy-connect-ca.hcl vault:/tmp/
docker exec -it vault /bin/sh
export VAULT_ADDR=http://127.0.0.1:8200
vault login <root_token>
vault status
vault token lookup

vault policy write connect-ca /tmp/vault-policy-connect-ca.hcl
```

3. Create Vault token for above policy

```
/tmp # vault token create -policy=connect-ca
WARNING! The following warnings were returned from Vault:

  * Endpoint ignored these unrecognized parameters: [display_name entity_alias
  explicit_max_ttl num_uses period policies renewable ttl type]

Key                  Value
---                  -----
token                hvs.CAESIMw9SBwp7VRipFd2mkUS_zXED6srfaTyYI4UtRl2RiGhGh4KHGh2cy5WTUFndmlET3p2WXNDR1ZUTno4VXB6dlY
token_accessor       aM5Fi1Daj2FuqVErSVi9Bv3O
token_duration       768h
token_renewable      true
token_policies       ["connect-ca" "default"]
identity_policies    []
policies             ["connect-ca" "default"]
```

4. Configure Consul CA provider with above Vault info, changes to be made in `./consul/server.hcl`

```
docker compose up consul -d
```

## Verify

Look at log

```
2022-08-15T23:27:55.359Z [INFO]  connect.ca.vault: Successfully renewed token for Vault provider
2022-08-15T23:27:55.844Z [INFO]  connect.ca: Correcting stored CARoot values: previous-signing-key=55:f3:f6:79:ba:d8:6d:be:bd:fe:a1:f1:9e:d4:d8:de:1f:01:66:dd updated-signing-key=61:3b:12:39:a4:3a:d9:3c:fd:a9:61:9e:34:2d:e2:a2:5b:63:2d:90
2022-08-15T23:27:55.850Z [INFO]  connect.ca: initialized primary datacenter CA with provider: provider=vault
```

5. Verify CA certificates work

```
/ # consul connect ca get-config
{
        "Provider": "vault",
        "Config": {
                "Address": "http://10.0.0.2:8200",
                "IntermediateCertTTL": "8760h",
                "IntermediatePKIPath": "connect_inter",
                "LeafCertTTL": "72h",
                "PrivateKeyBits": 2048,
                "PrivateKeyType": "rsa",
                "RootCertTTL": "87600h",
                "RootPKIPath": "connect_root",
                "Token": "hvs.CAESINBZxogueddxFnkw9HUEaXrIOL99NVTzEz5cpWVa83NJGh4KHGh2cy5KSlRiM21vVmVad0h6VmtOaUxnTG9UOVA",
                "rotation_period": "2160h"
        },
        "State": null,
        "ForceWithoutCrossSigning": false,
        "CreateIndex": 5,
        "ModifyIndex": 5
}

/ # curl http://localhost:8500/v1/connect/ca/roots?pretty
{
    "ActiveRootID": "7d:04:6d:eb:77:04:fa:7a:68:76:c5:7d:c6:e3:01:fb:da:66:02:f8",
    "TrustDomain": "42569264-53e0-d4c3-6a58-2bf84d8b6ff1.consul",
    "Roots": [
        {
            "ID": "7d:04:6d:eb:77:04:fa:7a:68:76:c5:7d:c6:e3:01:fb:da:66:02:f8",
            "Name": "Vault CA Primary Cert",
            "SerialNumber": 15547008373342817059,
            "SigningKeyID": "61:3b:12:39:a4:3a:d9:3c:fd:a9:61:9e:34:2d:e2:a2:5b:63:2d:90",
            "ExternalTrustDomain": "42569264-53e0-d4c3-6a58-2bf84d8b6ff1",
            "NotBefore": "2022-08-15T23:27:25Z",
            "NotAfter": "2032-08-12T23:27:55Z",
            "RootCert": "-----BEGIN CERTIFICATE-----\nMIIDuzCCAqOgAwIBAgIUS43w5OWgPeNwImYV18IRvnUfSyMwDQYJKoZIhvcNAQEL\nBQAwMDEuMCwGA1UEAxMlcHJpLWxmYmlzaWJ0LnZhdWx0LmNhLjQyNTY5MjY0LmNv\nbnN1bDAeFw0yMjA4MTUyMzI3MjVaFw0zMjA4MTIyMzI3NTVaMDAxLjAsBgNVBAMT\nJXByaS1sZmJpc2lidC52YXVsdC5jYS40MjU2OTI2NC5jb25zdWwwggEiMA0GCSqG\nSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDGxn7+31eCRGO4+qtuxMm80vuFi77wUNvN\n+RA3pEegPCGTeZCYwfGIO4+SbJ8DOh1jih9ffcrw33UDrhniGKSr9lRLxPclZwyC\nVJI70D5FKWWd0UUan/MjbqfPNRiFysdfMdLSkFpq9xfXaiQ9RLfH8FA5o8Xk5kr6\nfx5A6GBXlMcKBu8JfuXSrq/kEyLYuSu4Zi8MxWgS4GupOjFJallUXtOFIL+H+s+R\nQhLQBLyGytOI3+hA0snNNtO/ri+vzaJo9WfL1MBLGwaLFk1eLlNc949ktf95FTlp\nDYAe4E4MqUyyPBem4H6HslvyvXoMqqZmCp78PBY+HjzaLwNNH9SLAgMBAAGjgcww\ngckwDgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFFXz\n9nm62G2+vf6h8Z7U2N4fAWbdMB8GA1UdIwQYMBaAFFXz9nm62G2+vf6h8Z7U2N4f\nAWbdMGYGA1UdEQRfMF2CJXByaS1sZmJpc2lidC52YXVsdC5jYS40MjU2OTI2NC5j\nb25zdWyGNHNwaWZmZTovLzQyNTY5MjY0LTUzZTAtZDRjMy02YTU4LTJiZjg0ZDhi\nNmZmMS5jb25zdWwwDQYJKoZIhvcNAQELBQADggEBAG5XpWkuuOzTfcrlkHPmtFbf\nHuO2dUMjdTiGFSZ3/S9CsjKejo1m2Y5BRXgOOqjDtM8yNIf2HWi/jnRl5mHg+Vyt\n8T2Duw3SuqlwB8P5EKSrryM/PprvcI8HvPW/2VAuqK4ocHsAqyaabg/OhGWvYDLG\nCb1caG5pa+SuC24fphCkTij55PglwZn0rM8mFxF6HIQAPVEp1vBu2EYaXmHWLEWR\nzLXAj+aXPb35cUH9K2k8vtdzwh9vsxeNMcbPXd4ElvWMw1D209nSaFgmewpqKidc\nAPfw/4VE3RX63K/dgjckFuaQURHRLotRNBdDxBU9YOJE8CO2LuikACFl6Oh/t6c=\n-----END CERTIFICATE-----\n",
            "IntermediateCerts": [
                "-----BEGIN CERTIFICATE-----\nMIIDuzCCAqOgAwIBAgIUPaVuLonu18re8NNE7EU0u2xQUFIwDQYJKoZIhvcNAQEL\nBQAwMDEuMCwGA1UEAxMlcHJpLWxmYmlzaWJ0LnZhdWx0LmNhLjQyNTY5MjY0LmNv\nbnN1bDAeFw0yMjA4MTUyMzI3MjVaFw0yMzA4MTUyMzI3NTVaMDAxLjAsBgNVBAMT\nJXByaS0xM2J1ejZ4ZS52YXVsdC5jYS40MjU2OTI2NC5jb25zdWwwggEiMA0GCSqG\nSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDYwzorC819eJmq7S1v89OduCVQN7DVD1km\nM75bGEuZxEH2FqV2vsozsD2Xwx7L6yXDGhvirO4ssvCyC+Vog89r1hqLuXEaYAPp\nHbDcifYeJ8eqd2XSgQU8LF60QjaUdofGglFsqZHfNzOrMRK93w3txVvFxTBlGDeS\nLeGeSmG41EXDkfGvOz2nuas3LnwM5Y1WfvP/J7jSnvXnBL8WDR3gTEkQ0lUPp7eU\nzyYxR/pkzfq5qwOr9NRk2HNLItr6fH3XBqgfK+RsRrhcpLnpzVPmy3kTsu6RrKN8\nx+FlCPueCoOKUTKFU5qIijCyHzLHQMigEBJ6zzeG7rxbCsLgnmv5AgMBAAGjgcww\ngckwDgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFGE7\nEjmkOtk8/alhnjQt4qJbYy2QMB8GA1UdIwQYMBaAFFXz9nm62G2+vf6h8Z7U2N4f\nAWbdMGYGA1UdEQRfMF2CJXByaS0xM2J1ejZ4ZS52YXVsdC5jYS40MjU2OTI2NC5j\nb25zdWyGNHNwaWZmZTovLzQyNTY5MjY0LTUzZTAtZDRjMy02YTU4LTJiZjg0ZDhi\nNmZmMS5jb25zdWwwDQYJKoZIhvcNAQELBQADggEBABzqYQ1qPA2hglF9S5xkfOw1\nx6+Z5Vm+x/HHiN/uElLcHHvhFAaj7ufIalsZIm+7Dj2I1ifm5UiW+o23UlK0k/3F\nno8a0iKqHr5g8789qJDPZz4TOWKxlAbCRTNlVcQ81FBqvCeSZORjeqbhvrVCwPUT\nI2amwmOpKtkfSzhaVUxxzujzd6npkGJbMEfAPvmdOW2kxkK1msGfLDOr+iQ3R9OL\nuVOGdqkpYO1jbBM35sSrpmiism2ks9hN2IHu9eT5kSxIEgOA7fQ1bTNGK2vfHTq5\n8tjkEbAQO+fEZ0Ag9T+KGcs5N0QCnVLvxZC5CPhknMB3mK+O5yb3g+ASGhKh3DU=\n-----END CERTIFICATE-----\n"
            ],
            "Active": true,
            "PrivateKeyType": "rsa",
            "PrivateKeyBits": 2048,
            "CreateIndex": 6,
            "ModifyIndex": 6
        }
    ]
}
```

```
openssl x509 -in primary-root.crt -text -noout

Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            4b:8d:f0:e4:e5:a0:3d:e3:70:22:66:15:d7:c2:11:be:75:1f:4b:23
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN=pri-lfbisibt.vault.ca.42569264.consul
        Validity
            Not Before: Aug 15 23:27:25 2022 GMT
            Not After : Aug 12 23:27:55 2032 GMT
        Subject: CN=pri-lfbisibt.vault.ca.42569264.consul
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:c6:c6:7e:fe:df:57:82:44:63:b8:fa:ab:6e:c4:
                    c9:bc:d2:fb:85:8b:be:f0:50:db:cd:f9:10:37:a4:
                    47:a0:3c:21:93:79:90:98:c1:f1:88:3b:8f:92:6c:
                    9f:03:3a:1d:63:8a:1f:5f:7d:ca:f0:df:75:03:ae:
                    19:e2:18:a4:ab:f6:54:4b:c4:f7:25:67:0c:82:54:
                    92:3b:d0:3e:45:29:65:9d:d1:45:1a:9f:f3:23:6e:
                    a7:cf:35:18:85:ca:c7:5f:31:d2:d2:90:5a:6a:f7:
                    17:d7:6a:24:3d:44:b7:c7:f0:50:39:a3:c5:e4:e6:
                    4a:fa:7f:1e:40:e8:60:57:94:c7:0a:06:ef:09:7e:
                    e5:d2:ae:af:e4:13:22:d8:b9:2b:b8:66:2f:0c:c5:
                    68:12:e0:6b:a9:3a:31:49:6a:59:54:5e:d3:85:20:
                    bf:87:fa:cf:91:42:12:d0:04:bc:86:ca:d3:88:df:
                    e8:40:d2:c9:cd:36:d3:bf:ae:2f:af:cd:a2:68:f5:
                    67:cb:d4:c0:4b:1b:06:8b:16:4d:5e:2e:53:5c:f7:
                    8f:64:b5:ff:79:15:39:69:0d:80:1e:e0:4e:0c:a9:
                    4c:b2:3c:17:a6:e0:7e:87:b2:5b:f2:bd:7a:0c:aa:
                    a6:66:0a:9e:fc:3c:16:3e:1e:3c:da:2f:03:4d:1f:
                    d4:8b
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Certificate Sign, CRL Sign
            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Subject Key Identifier: 
                55:F3:F6:79:BA:D8:6D:BE:BD:FE:A1:F1:9E:D4:D8:DE:1F:01:66:DD
            X509v3 Authority Key Identifier: 
                keyid:55:F3:F6:79:BA:D8:6D:BE:BD:FE:A1:F1:9E:D4:D8:DE:1F:01:66:DD

            X509v3 Subject Alternative Name: 
                DNS:pri-lfbisibt.vault.ca.42569264.consul, URI:spiffe://42569264-53e0-d4c3-6a58-2bf84d8b6ff1.consul
    Signature Algorithm: sha256WithRSAEncryption
         6e:57:a5:69:2e:b8:ec:d3:7d:ca:e5:90:73:e6:b4:56:df:1e:
         e3:b6:75:43:23:75:38:86:15:26:77:fd:2f:42:b2:32:9e:8e:
         8d:66:d9:8e:41:45:78:0e:3a:a8:c3:b4:cf:32:34:87:f6:1d:
         68:bf:8e:74:65:e6:61:e0:f9:5c:ad:f1:3d:83:bb:0d:d2:ba:
         a9:70:07:c3:f9:10:a4:ab:af:23:3f:3e:9a:ef:70:8f:07:bc:
         f5:bf:d9:50:2e:a8:ae:28:70:7b:00:ab:26:9a:6e:0f:ce:84:
         65:af:60:32:c6:09:bd:5c:68:6e:69:6b:e4:ae:0b:6e:1f:a6:
         10:a4:4e:28:f9:e4:f8:25:c1:99:f4:ac:cf:26:17:11:7a:1c:
         84:00:3d:51:29:d6:f0:6e:d8:46:1a:5e:61:d6:2c:45:91:cc:
         b5:c0:8f:e6:97:3d:bd:f9:71:41:fd:2b:69:3c:be:d7:73:c2:
         1f:6f:b3:17:8d:31:c6:cf:5d:de:04:96:f5:8c:c3:50:f6:d3:
         d9:d2:68:58:26:7b:0a:6a:2a:27:5c:00:f7:f0:ff:85:44:dd:
         15:fa:dc:af:dd:82:37:24:16:e6:90:51:11:d1:2e:8b:51:34:
         17:43:c4:15:3d:60:e2:44:f0:23:b6:2e:e8:a4:00:21:65:e8:
         e8:7f:b7:a7

openssl x509 -in primary-inter.crt -text -noout

Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            3d:a5:6e:2e:89:ee:d7:ca:de:f0:d3:44:ec:45:34:bb:6c:50:50:52
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN=pri-lfbisibt.vault.ca.42569264.consul
        Validity
            Not Before: Aug 15 23:27:25 2022 GMT
            Not After : Aug 15 23:27:55 2023 GMT
        Subject: CN=pri-13buz6xe.vault.ca.42569264.consul
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:d8:c3:3a:2b:0b:cd:7d:78:99:aa:ed:2d:6f:f3:
                    d3:9d:b8:25:50:37:b0:d5:0f:59:26:33:be:5b:18:
                    4b:99:c4:41:f6:16:a5:76:be:ca:33:b0:3d:97:c3:
                    1e:cb:eb:25:c3:1a:1b:e2:ac:ee:2c:b2:f0:b2:0b:
                    e5:68:83:cf:6b:d6:1a:8b:b9:71:1a:60:03:e9:1d:
                    b0:dc:89:f6:1e:27:c7:aa:77:65:d2:81:05:3c:2c:
                    5e:b4:42:36:94:76:87:c6:82:51:6c:a9:91:df:37:
                    33:ab:31:12:bd:df:0d:ed:c5:5b:c5:c5:30:65:18:
                    37:92:2d:e1:9e:4a:61:b8:d4:45:c3:91:f1:af:3b:
                    3d:a7:b9:ab:37:2e:7c:0c:e5:8d:56:7e:f3:ff:27:
                    b8:d2:9e:f5:e7:04:bf:16:0d:1d:e0:4c:49:10:d2:
                    55:0f:a7:b7:94:cf:26:31:47:fa:64:cd:fa:b9:ab:
                    03:ab:f4:d4:64:d8:73:4b:22:da:fa:7c:7d:d7:06:
                    a8:1f:2b:e4:6c:46:b8:5c:a4:b9:e9:cd:53:e6:cb:
                    79:13:b2:ee:91:ac:a3:7c:c7:e1:65:08:fb:9e:0a:
                    83:8a:51:32:85:53:9a:88:8a:30:b2:1f:32:c7:40:
                    c8:a0:10:12:7a:cf:37:86:ee:bc:5b:0a:c2:e0:9e:
                    6b:f9
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Certificate Sign, CRL Sign
            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Subject Key Identifier: 
                61:3B:12:39:A4:3A:D9:3C:FD:A9:61:9E:34:2D:E2:A2:5B:63:2D:90
            X509v3 Authority Key Identifier: 
                keyid:55:F3:F6:79:BA:D8:6D:BE:BD:FE:A1:F1:9E:D4:D8:DE:1F:01:66:DD

            X509v3 Subject Alternative Name: 
                DNS:pri-13buz6xe.vault.ca.42569264.consul, URI:spiffe://42569264-53e0-d4c3-6a58-2bf84d8b6ff1.consul
    Signature Algorithm: sha256WithRSAEncryption
         1c:ea:61:0d:6a:3c:0d:a1:82:51:7d:4b:9c:64:7c:ec:35:c7:
         af:99:e5:59:be:c7:f1:c7:88:df:ee:12:52:dc:1c:7b:e1:14:
         06:a3:ee:e7:c8:6a:5b:19:22:6f:bb:0e:3d:88:d6:27:e6:e5:
         48:96:fa:8d:b7:52:52:b4:93:fd:c5:9e:8f:1a:d2:22:aa:1e:
         be:60:f3:bf:3d:a8:90:cf:67:3e:13:39:62:b1:94:06:c2:45:
         33:65:55:c4:3c:d4:50:6a:bc:27:92:64:e4:63:7a:a6:e1:be:
         b5:42:c0:f5:13:23:66:a6:c2:63:a9:2a:d9:1f:4b:38:5a:55:
         4c:71:ce:e8:f3:77:a9:e9:90:62:5b:30:47:c0:3e:f9:9d:39:
         6d:a4:c6:42:b5:9a:c1:9f:2c:33:ab:fa:24:37:47:d3:8b:b9:
         53:86:76:a9:29:60:ed:63:6c:13:37:e6:c4:ab:a6:68:a2:b2:
         6d:a4:b3:d8:4d:d8:81:ee:f5:e4:f9:91:2c:48:12:03:80:ed:
         f4:35:6d:33:46:2b:6b:df:1d:3a:b9:f2:d8:e4:11:b0:10:3b:
         e7:c4:67:40:20:f5:3f:8a:19:cb:39:37:44:02:9d:52:ef:c5:
         90:b9:08:f8:64:9c:c0:77:98:af:8e:e7:26:f7:83:e0:12:1a:
         12:a1:dc:35

```

- Register a test service

```
curl \
    --request PUT \
    --data @web.json \
    http://127.0.0.1:8500/v1/agent/service/register?replace-existing-checks=true

curl localhost:8500/v1/agent/connect/ca/leaf/web
{"SerialNumber":"3f:18:0b:6c:61:4b:d7:f5:42:88:b7:9e:69:03:c0:2a:52:50:b1:2f","CertPEM":"-----BEGIN CERTIFICATE-----\nMIICxDCCAaygAwIBAgIUPxgLbGFL1/VCiLeeaQPAKlJQsS8wDQYJKoZIhvcNAQEL\nBQAwMDEuMCwGA1UEAxMlcHJpLTEzYnV6NnhlLnZhdWx0LmNhLjQyNTY5MjY0LmNv\nbnN1bDAeFw0yMjA4MTYwMDI4NTNaFw0yMjA4MTkwMDI5MjNaMAAwWTATBgcqhkjO\nPQIBBggqhkjOPQMBBwNCAASDN1QTIDI8HMqbrGuA/SWQylJDLCnvBQV7KFLo5WX+\n6ZMnPL5vwYi7IRwyilIFiVgSpvlbEeSi7eIyipejTEHQo4HQMIHNMA4GA1UdDwEB\n/wQEAwIDqDAdBgNVHSUEFjAUBggrBgEFBQcDAQYIKwYBBQUHAwIwHQYDVR0OBBYE\nFNuTyo8PCSt10lvlLHyqijoUQc2yMB8GA1UdIwQYMBaAFGE7EjmkOtk8/alhnjQt\n4qJbYy2QMFwGA1UdEQEB/wRSMFCGTnNwaWZmZTovLzQyNTY5MjY0LTUzZTAt
/tmp # curl localhost:8500/v1/agent/connect/ca/leaf/web?pretty
{
    "SerialNumber": "3f:18:0b:6c:61:4b:d7:f5:42:88:b7:9e:69:03:c0:2a:52:50:b1:2f",
    "CertPEM": "-----BEGIN CERTIFICATE-----\nMIICxDCCAaygAwIBAgIUPxgLbGFL1/VCiLeeaQPAKlJQsS8wDQYJKoZIhvcNAQEL\nBQAwMDEuMCwGA1UEAxMlcHJpLTEzYnV6NnhlLnZhdWx0LmNhLjQyNTY5MjY0LmNv\nbnN1bDAeFw0yMjA4MTYwMDI4NTNaFw0yMjA4MTkwMDI5MjNaMAAwWTATBgcqhkjO\nPQIBBggqhkjOPQMBBwNCAASDN1QTIDI8HMqbrGuA/SWQylJDLCnvBQV7KFLo5WX+\n6ZMnPL5vwYi7IRwyilIFiVgSpvlbEeSi7eIyipejTEHQo4HQMIHNMA4GA1UdDwEB\n/wQEAwIDqDAdBgNVHSUEFjAUBggrBgEFBQcDAQYIKwYBBQUHAwIwHQYDVR0OBBYE\nFNuTyo8PCSt10lvlLHyqijoUQc2yMB8GA1UdIwQYMBaAFGE7EjmkOtk8/alhnjQt\n4qJbYy2QMFwGA1UdEQEB/wRSMFCGTnNwaWZmZTovLzQyNTY5MjY0LTUzZTAtZDRj\nMy02YTU4LTJiZjg0ZDhiNmZmMS5jb25zdWwvbnMvZGVmYXVsdC9kYy9kYzEvc3Zj\nL3dlYjANBgkqhkiG9w0BAQsFAAOCAQEAjxUWZfb65KoyPDtX75yimCp88GKD3N7M\n1f0QlGmR103ECGJTiVSSe0RM4A8BYFBypQv8gInS+5bfk9zyHBEAAsPqmNVHM3Md\nHqhTP29lTWOMLKFnyij8pGaq8R/GRd2hq9KsoBkjh3qhcjltenx3T8Ii/hoL/OiL\n/q5wDoPB/j7g38btyJH1WOI1EsbHDH175c9HIYCa/UVnEROFVvaGI8Xa8JG+J62f\nZ6zuEsMzQHRxblxD86NHvLpk0oH1zwb+0+Vh+4a7IN3TgUHZM1V+j6Kb/TaGE6cP\nh69uFZ1dXdMPAbQvSo7Z1oJfuwkeZ64DZPTOmX5bfFxcShjg+uYKpw==\n-----END CERTIFICATE-----\n-----BEGIN CERTIFICATE-----\nMIIDuzCCAqOgAwIBAgIUPaVuLonu18re8NNE7EU0u2xQUFIwDQYJKoZIhvcNAQEL\nBQAwMDEuMCwGA1UEAxMlcHJpLWxmYmlzaWJ0LnZhdWx0LmNhLjQyNTY5MjY0LmNv\nbnN1bDAeFw0yMjA4MTUyMzI3MjVaFw0yMzA4MTUyMzI3NTVaMDAxLjAsBgNVBAMT\nJXByaS0xM2J1ejZ4ZS52YXVsdC5jYS40MjU2OTI2NC5jb25zdWwwggEiMA0GCSqG\nSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDYwzorC819eJmq7S1v89OduCVQN7DVD1km\nM75bGEuZxEH2FqV2vsozsD2Xwx7L6yXDGhvirO4ssvCyC+Vog89r1hqLuXEaYAPp\nHbDcifYeJ8eqd2XSgQU8LF60QjaUdofGglFsqZHfNzOrMRK93w3txVvFxTBlGDeS\nLeGeSmG41EXDkfGvOz2nuas3LnwM5Y1WfvP/J7jSnvXnBL8WDR3gTEkQ0lUPp7eU\nzyYxR/pkzfq5qwOr9NRk2HNLItr6fH3XBqgfK+RsRrhcpLnpzVPmy3kTsu6RrKN8\nx+FlCPueCoOKUTKFU5qIijCyHzLHQMigEBJ6zzeG7rxbCsLgnmv5AgMBAAGjgcww\ngckwDgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFGE7\nEjmkOtk8/alhnjQt4qJbYy2QMB8GA1UdIwQYMBaAFFXz9nm62G2+vf6h8Z7U2N4f\nAWbdMGYGA1UdEQRfMF2CJXByaS0xM2J1ejZ4ZS52YXVsdC5jYS40MjU2OTI2NC5j\nb25zdWyGNHNwaWZmZTovLzQyNTY5MjY0LTUzZTAtZDRjMy02YTU4LTJiZjg0ZDhi\nNmZmMS5jb25zdWwwDQYJKoZIhvcNAQELBQADggEBABzqYQ1qPA2hglF9S5xkfOw1\nx6+Z5Vm+x/HHiN/uElLcHHvhFAaj7ufIalsZIm+7Dj2I1ifm5UiW+o23UlK0k/3F\nno8a0iKqHr5g8789qJDPZz4TOWKxlAbCRTNlVcQ81FBqvCeSZORjeqbhvrVCwPUT\nI2amwmOpKtkfSzhaVUxxzujzd6npkGJbMEfAPvmdOW2kxkK1msGfLDOr+iQ3R9OL\nuVOGdqkpYO1jbBM35sSrpmiism2ks9hN2IHu9eT5kSxIEgOA7fQ1bTNGK2vfHTq5\n8tjkEbAQO+fEZ0Ag9T+KGcs5N0QCnVLvxZC5CPhknMB3mK+O5yb3g+ASGhKh3DU=\n-----END CERTIFICATE-----\n",
    "PrivateKeyPEM": "-----BEGIN EC PRIVATE KEY-----\nMHcCAQEEIGCHSOQryOhlfpyrdr5IFilV3BflV15TTEqlFJSiY+DqoAoGCCqGSM49\nAwEHoUQDQgAEgzdUEyAyPBzKm6xrgP0lkMpSQywp7wUFeyhS6OVl/umTJzy+b8GI\nuyEcMopSBYlYEqb5WxHkou3iMoqXo0xB0A==\n-----END EC PRIVATE KEY-----\n",
    "Service": "web",
    "ServiceURI": "spiffe://42569264-53e0-d4c3-6a58-2bf84d8b6ff1.consul/ns/default/dc/dc1/svc/web",
    "ValidAfter": "2022-08-16T00:28:53Z",
    "ValidBefore": "2022-08-19T00:29:23Z",
    "CreateIndex": 237,
    "ModifyIndex": 237
}
```


7. Create a secondary cluster, WAN federated and Connect enabled

- Verify that the CA cert in secondary data center is signed by primary data center

Look into secondary cluster log

```
2022-08-16T20:51:58.793Z [DEBUG] connect.ca: starting Connect CA root replication from primary datacenter: primary=dc1
```

```
curl http://localhost:8500/v1/connect/ca/roots?pretty
{
    "ActiveRootID": "7d:04:6d:eb:77:04:fa:7a:68:76:c5:7d:c6:e3:01:fb:da:66:02:f8",
    "TrustDomain": "42569264-53e0-d4c3-6a58-2bf84d8b6ff1.consul",
    "Roots": [
        {
            "ID": "7d:04:6d:eb:77:04:fa:7a:68:76:c5:7d:c6:e3:01:fb:da:66:02:f8",
            "Name": "Vault CA Primary Cert",
            "SerialNumber": 15547008373342817059,
            "SigningKeyID": "ca:60:ef:32:37:24:c2:49:6c:bd:2e:8a:9c:ec:89:8e:e9:b3:b6:dd",
            "ExternalTrustDomain": "42569264-53e0-d4c3-6a58-2bf84d8b6ff1",
            "NotBefore": "2022-08-15T23:27:25Z",
            "NotAfter": "2032-08-12T23:27:55Z",
            "RootCert": "-----BEGIN CERTIFICATE-----\nMIIDuzCCAqOgAwIBAgIUS43w5OWgPeNwImYV18IRvnUfSyMwDQYJKoZIhvcNAQEL\nBQAwMDEuMCwGA1UEAxMlcHJpLWxmYmlzaWJ0LnZhdWx0LmNhLjQyNTY5MjY0LmNv\nbnN1bDAeFw0yMjA4MTUyMzI3MjVaFw0zMjA4MTIyMzI3NTVaMDAxLjAsBgNVBAMT\nJXByaS1sZmJpc2lidC52YXVsdC5jYS40MjU2OTI2NC5jb25zdWwwggEiMA0GCSqG\nSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDGxn7+31eCRGO4+qtuxMm80vuFi77wUNvN\n+RA3pEegPCGTeZCYwfGIO4+SbJ8DOh1jih9ffcrw33UDrhniGKSr9lRLxPclZwyC\nVJI70D5FKWWd0UUan/MjbqfPNRiFysdfMdLSkFpq9xfXaiQ9RLfH8FA5o8Xk5kr6\nfx5A6GBXlMcKBu8JfuXSrq/kEyLYuSu4Zi8MxWgS4GupOjFJallUXtOFIL+H+s+R\nQhLQBLyGytOI3+hA0snNNtO/ri+vzaJo9WfL1MBLGwaLFk1eLlNc949ktf95FTlp\nDYAe4E4MqUyyPBem4H6HslvyvXoMqqZmCp78PBY+HjzaLwNNH9SLAgMBAAGjgcww\ngckwDgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFFXz\n9nm62G2+vf6h8Z7U2N4fAWbdMB8GA1UdIwQYMBaAFFXz9nm62G2+vf6h8Z7U2N4f\nAWbdMGYGA1UdEQRfMF2CJXByaS1sZmJpc2lidC52YXVsdC5jYS40MjU2OTI2NC5j\nb25zdWyGNHNwaWZmZTovLzQyNTY5MjY0LTUzZTAtZDRjMy02YTU4LTJiZjg0ZDhi\nNmZmMS5jb25zdWwwDQYJKoZIhvcNAQELBQADggEBAG5XpWkuuOzTfcrlkHPmtFbf\nHuO2dUMjdTiGFSZ3/S9CsjKejo1m2Y5BRXgOOqjDtM8yNIf2HWi/jnRl5mHg+Vyt\n8T2Duw3SuqlwB8P5EKSrryM/PprvcI8HvPW/2VAuqK4ocHsAqyaabg/OhGWvYDLG\nCb1caG5pa+SuC24fphCkTij55PglwZn0rM8mFxF6HIQAPVEp1vBu2EYaXmHWLEWR\nzLXAj+aXPb35cUH9K2k8vtdzwh9vsxeNMcbPXd4ElvWMw1D209nSaFgmewpqKidc\nAPfw/4VE3RX63K/dgjckFuaQURHRLotRNBdDxBU9YOJE8CO2LuikACFl6Oh/t6c=\n-----END CERTIFICATE-----\n",
            "IntermediateCerts": [
                "-----BEGIN CERTIFICATE-----\nMIIDuzCCAqOgAwIBAgIUPaVuLonu18re8NNE7EU0u2xQUFIwDQYJKoZIhvcNAQEL\nBQAwMDEuMCwGA1UEAxMlcHJpLWxmYmlzaWJ0LnZhdWx0LmNhLjQyNTY5MjY0LmNv\nbnN1bDAeFw0yMjA4MTUyMzI3MjVaFw0yMzA4MTUyMzI3NTVaMDAxLjAsBgNVBAMT\nJXByaS0xM2J1ejZ4ZS52YXVsdC5jYS40MjU2OTI2NC5jb25zdWwwggEiMA0GCSqG\nSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDYwzorC819eJmq7S1v89OduCVQN7DVD1km\nM75bGEuZxEH2FqV2vsozsD2Xwx7L6yXDGhvirO4ssvCyC+Vog89r1hqLuXEaYAPp\nHbDcifYeJ8eqd2XSgQU8LF60QjaUdofGglFsqZHfNzOrMRK93w3txVvFxTBlGDeS\nLeGeSmG41EXDkfGvOz2nuas3LnwM5Y1WfvP/J7jSnvXnBL8WDR3gTEkQ0lUPp7eU\nzyYxR/pkzfq5qwOr9NRk2HNLItr6fH3XBqgfK+RsRrhcpLnpzVPmy3kTsu6RrKN8\nx+FlCPueCoOKUTKFU5qIijCyHzLHQMigEBJ6zzeG7rxbCsLgnmv5AgMBAAGjgcww\ngckwDgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFGE7\nEjmkOtk8/alhnjQt4qJbYy2QMB8GA1UdIwQYMBaAFFXz9nm62G2+vf6h8Z7U2N4f\nAWbdMGYGA1UdEQRfMF2CJXByaS0xM2J1ejZ4ZS52YXVsdC5jYS40MjU2OTI2NC5j\nb25zdWyGNHNwaWZmZTovLzQyNTY5MjY0LTUzZTAtZDRjMy02YTU4LTJiZjg0ZDhi\nNmZmMS5jb25zdWwwDQYJKoZIhvcNAQELBQADggEBABzqYQ1qPA2hglF9S5xkfOw1\nx6+Z5Vm+x/HHiN/uElLcHHvhFAaj7ufIalsZIm+7Dj2I1ifm5UiW+o23UlK0k/3F\nno8a0iKqHr5g8789qJDPZz4TOWKxlAbCRTNlVcQ81FBqvCeSZORjeqbhvrVCwPUT\nI2amwmOpKtkfSzhaVUxxzujzd6npkGJbMEfAPvmdOW2kxkK1msGfLDOr+iQ3R9OL\nuVOGdqkpYO1jbBM35sSrpmiism2ks9hN2IHu9eT5kSxIEgOA7fQ1bTNGK2vfHTq5\n8tjkEbAQO+fEZ0Ag9T+KGcs5N0QCnVLvxZC5CPhknMB3mK+O5yb3g+ASGhKh3DU=\n-----END CERTIFICATE-----\n",
                "-----BEGIN CERTIFICATE-----\nMIICnzCCAYegAwIBAgIUYoObcf42Xxzg9Ie8O66xJmSFwucwDQYJKoZIhvcNAQEL\nBQAwMDEuMCwGA1UEAxMlcHJpLWxmYmlzaWJ0LnZhdWx0LmNhLjQyNTY5MjY0LmNv\nbnN1bDAeFw0yMjA4MTYyMDUxMjhaFw0yMzA4MTYyMDUxNThaMAAwWTATBgcqhkjO\nPQIBBggqhkjOPQMBBwNCAARnKCeGmmlLl2GStkXMuOWnKrhIPdp9cr2Hj5RLOUD3\ncEceenZ+onwdev/KedatBL2sb/dSatSo6LDT+LMgGpaAo4GrMIGoMA4GA1UdDwEB\n/wQEAwIBBjASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQWBBTKYO8yNyTCSWy9\nLoqc7ImO6bO23TAfBgNVHSMEGDAWgBRV8/Z5uthtvr3+ofGe1NjeHwFm3TBCBgNV\nHREBAf8EODA2hjRzcGlmZmU6Ly80MjU2OTI2NC01M2UwLWQ0YzMtNmE1OC0yYmY4\nNGQ4YjZmZjEuY29uc3VsMA0GCSqGSIb3DQEBCwUAA4IBAQCATkRjUW+SdFVV39SQ\nYk4DTW15P7mSx2azJcwpQFFHZQww7K3vwtzw0uhERmBq3iy3ZFIxa88AjgnzmPDF\nOUC6b+UUr95y5ut0D8ms97BIi1QEmm7UCK+UWgfmqgPNhccSvUPTxJVQDYpQOHXB\n66iTS/m8JQsUsFMmhZ1Uu3sv+N+UOGhN2RHEA8jG8ewyVg2vfKPpQ4U2YcvpmI9F\nQO0YcZrmwC/IjiP9s3cXBDSB+3v6WCSRdF2vM9pVZFhR0XfNnEcvkr2Q5FVLQnRv\nfqen/Yym+HqFrJI7eRXVmXAksEHtXZZBr39n6OmDpY08pQLCCq97NjpNAewXgGPt\nkwuk\n-----END CERTIFICATE-----\n-----BEGIN CERTIFICATE-----\nMIIDuzCCAqOgAwIBAgIUS43w5OWgPeNwImYV18IRvnUfSyMwDQYJKoZIhvcNAQEL\nBQAwMDEuMCwGA1UEAxMlcHJpLWxmYmlzaWJ0LnZhdWx0LmNhLjQyNTY5MjY0LmNv\nbnN1bDAeFw0yMjA4MTUyMzI3MjVaFw0zMjA4MTIyMzI3NTVaMDAxLjAsBgNVBAMT\nJXByaS1sZmJpc2lidC52YXVsdC5jYS40MjU2OTI2NC5jb25zdWwwggEiMA0GCSqG\nSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDGxn7+31eCRGO4+qtuxMm80vuFi77wUNvN\n+RA3pEegPCGTeZCYwfGIO4+SbJ8DOh1jih9ffcrw33UDrhniGKSr9lRLxPclZwyC\nVJI70D5FKWWd0UUan/MjbqfPNRiFysdfMdLSkFpq9xfXaiQ9RLfH8FA5o8Xk5kr6\nfx5A6GBXlMcKBu8JfuXSrq/kEyLYuSu4Zi8MxWgS4GupOjFJallUXtOFIL+H+s+R\nQhLQBLyGytOI3+hA0snNNtO/ri+vzaJo9WfL1MBLGwaLFk1eLlNc949ktf95FTlp\nDYAe4E4MqUyyPBem4H6HslvyvXoMqqZmCp78PBY+HjzaLwNNH9SLAgMBAAGjgcww\ngckwDgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFFXz\n9nm62G2+vf6h8Z7U2N4fAWbdMB8GA1UdIwQYMBaAFFXz9nm62G2+vf6h8Z7U2N4f\nAWbdMGYGA1UdEQRfMF2CJXByaS1sZmJpc2lidC52YXVsdC5jYS40MjU2OTI2NC5j\nb25zdWyGNHNwaWZmZTovLzQyNTY5MjY0LTUzZTAtZDRjMy02YTU4LTJiZjg0ZDhi\nNmZmMS5jb25zdWwwDQYJKoZIhvcNAQELBQADggEBAG5XpWkuuOzTfcrlkHPmtFbf\nHuO2dUMjdTiGFSZ3/S9CsjKejo1m2Y5BRXgOOqjDtM8yNIf2HWi/jnRl5mHg+Vyt\n8T2Duw3SuqlwB8P5EKSrryM/PprvcI8HvPW/2VAuqK4ocHsAqyaabg/OhGWvYDLG\nCb1caG5pa+SuC24fphCkTij55PglwZn0rM8mFxF6HIQAPVEp1vBu2EYaXmHWLEWR\nzLXAj+aXPb35cUH9K2k8vtdzwh9vsxeNMcbPXd4ElvWMw1D209nSaFgmewpqKidc\nAPfw/4VE3RX63K/dgjckFuaQURHRLotRNBdDxBU9YOJE8CO2LuikACFl6Oh/t6c=\n-----END CERTIFICATE-----\n"
            ],
            "Active": true,
            "PrivateKeyType": "rsa",
            "PrivateKeyBits": 2048,
            "CreateIndex": 22,
            "ModifyIndex": 22
        }
    ]
}

openssl x509 -in secondary-root.crt -text -noout
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            4b:8d:f0:e4:e5:a0:3d:e3:70:22:66:15:d7:c2:11:be:75:1f:4b:23
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN=pri-lfbisibt.vault.ca.42569264.consul
        Validity
            Not Before: Aug 15 23:27:25 2022 GMT
            Not After : Aug 12 23:27:55 2032 GMT
        Subject: CN=pri-lfbisibt.vault.ca.42569264.consul
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:c6:c6:7e:fe:df:57:82:44:63:b8:fa:ab:6e:c4:
                    c9:bc:d2:fb:85:8b:be:f0:50:db:cd:f9:10:37:a4:
                    47:a0:3c:21:93:79:90:98:c1:f1:88:3b:8f:92:6c:
                    9f:03:3a:1d:63:8a:1f:5f:7d:ca:f0:df:75:03:ae:
                    19:e2:18:a4:ab:f6:54:4b:c4:f7:25:67:0c:82:54:
                    92:3b:d0:3e:45:29:65:9d:d1:45:1a:9f:f3:23:6e:
                    a7:cf:35:18:85:ca:c7:5f:31:d2:d2:90:5a:6a:f7:
                    17:d7:6a:24:3d:44:b7:c7:f0:50:39:a3:c5:e4:e6:
                    4a:fa:7f:1e:40:e8:60:57:94:c7:0a:06:ef:09:7e:
                    e5:d2:ae:af:e4:13:22:d8:b9:2b:b8:66:2f:0c:c5:
                    68:12:e0:6b:a9:3a:31:49:6a:59:54:5e:d3:85:20:
                    bf:87:fa:cf:91:42:12:d0:04:bc:86:ca:d3:88:df:
                    e8:40:d2:c9:cd:36:d3:bf:ae:2f:af:cd:a2:68:f5:
                    67:cb:d4:c0:4b:1b:06:8b:16:4d:5e:2e:53:5c:f7:
                    8f:64:b5:ff:79:15:39:69:0d:80:1e:e0:4e:0c:a9:
                    4c:b2:3c:17:a6:e0:7e:87:b2:5b:f2:bd:7a:0c:aa:
                    a6:66:0a:9e:fc:3c:16:3e:1e:3c:da:2f:03:4d:1f:
                    d4:8b
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Certificate Sign, CRL Sign
            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Subject Key Identifier: 
                55:F3:F6:79:BA:D8:6D:BE:BD:FE:A1:F1:9E:D4:D8:DE:1F:01:66:DD
            X509v3 Authority Key Identifier: 
                keyid:55:F3:F6:79:BA:D8:6D:BE:BD:FE:A1:F1:9E:D4:D8:DE:1F:01:66:DD

            X509v3 Subject Alternative Name: 
                DNS:pri-lfbisibt.vault.ca.42569264.consul, URI:spiffe://42569264-53e0-d4c3-6a58-2bf84d8b6ff1.consul
    Signature Algorithm: sha256WithRSAEncryption
         6e:57:a5:69:2e:b8:ec:d3:7d:ca:e5:90:73:e6:b4:56:df:1e:
         e3:b6:75:43:23:75:38:86:15:26:77:fd:2f:42:b2:32:9e:8e:
         8d:66:d9:8e:41:45:78:0e:3a:a8:c3:b4:cf:32:34:87:f6:1d:
         68:bf:8e:74:65:e6:61:e0:f9:5c:ad:f1:3d:83:bb:0d:d2:ba:
         a9:70:07:c3:f9:10:a4:ab:af:23:3f:3e:9a:ef:70:8f:07:bc:
         f5:bf:d9:50:2e:a8:ae:28:70:7b:00:ab:26:9a:6e:0f:ce:84:
         65:af:60:32:c6:09:bd:5c:68:6e:69:6b:e4:ae:0b:6e:1f:a6:
         10:a4:4e:28:f9:e4:f8:25:c1:99:f4:ac:cf:26:17:11:7a:1c:
         84:00:3d:51:29:d6:f0:6e:d8:46:1a:5e:61:d6:2c:45:91:cc:
         b5:c0:8f:e6:97:3d:bd:f9:71:41:fd:2b:69:3c:be:d7:73:c2:
         1f:6f:b3:17:8d:31:c6:cf:5d:de:04:96:f5:8c:c3:50:f6:d3:
         d9:d2:68:58:26:7b:0a:6a:2a:27:5c:00:f7:f0:ff:85:44:dd:
         15:fa:dc:af:dd:82:37:24:16:e6:90:51:11:d1:2e:8b:51:34:
         17:43:c4:15:3d:60:e2:44:f0:23:b6:2e:e8:a4:00:21:65:e8:
         e8:7f:b7:a7

Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            3d:a5:6e:2e:89:ee:d7:ca:de:f0:d3:44:ec:45:34:bb:6c:50:50:52
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN=pri-lfbisibt.vault.ca.42569264.consul
        Validity
            Not Before: Aug 15 23:27:25 2022 GMT
            Not After : Aug 15 23:27:55 2023 GMT
        Subject: CN=pri-13buz6xe.vault.ca.42569264.consul
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:d8:c3:3a:2b:0b:cd:7d:78:99:aa:ed:2d:6f:f3:
                    d3:9d:b8:25:50:37:b0:d5:0f:59:26:33:be:5b:18:
                    4b:99:c4:41:f6:16:a5:76:be:ca:33:b0:3d:97:c3:
                    1e:cb:eb:25:c3:1a:1b:e2:ac:ee:2c:b2:f0:b2:0b:
                    e5:68:83:cf:6b:d6:1a:8b:b9:71:1a:60:03:e9:1d:
                    b0:dc:89:f6:1e:27:c7:aa:77:65:d2:81:05:3c:2c:
                    5e:b4:42:36:94:76:87:c6:82:51:6c:a9:91:df:37:
                    33:ab:31:12:bd:df:0d:ed:c5:5b:c5:c5:30:65:18:
                    37:92:2d:e1:9e:4a:61:b8:d4:45:c3:91:f1:af:3b:
                    3d:a7:b9:ab:37:2e:7c:0c:e5:8d:56:7e:f3:ff:27:
                    b8:d2:9e:f5:e7:04:bf:16:0d:1d:e0:4c:49:10:d2:
                    55:0f:a7:b7:94:cf:26:31:47:fa:64:cd:fa:b9:ab:
                    03:ab:f4:d4:64:d8:73:4b:22:da:fa:7c:7d:d7:06:
                    a8:1f:2b:e4:6c:46:b8:5c:a4:b9:e9:cd:53:e6:cb:
                    79:13:b2:ee:91:ac:a3:7c:c7:e1:65:08:fb:9e:0a:
                    83:8a:51:32:85:53:9a:88:8a:30:b2:1f:32:c7:40:
                    c8:a0:10:12:7a:cf:37:86:ee:bc:5b:0a:c2:e0:9e:
                    6b:f9
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Certificate Sign, CRL Sign
            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Subject Key Identifier: 
                61:3B:12:39:A4:3A:D9:3C:FD:A9:61:9E:34:2D:E2:A2:5B:63:2D:90
            X509v3 Authority Key Identifier: 
                keyid:55:F3:F6:79:BA:D8:6D:BE:BD:FE:A1:F1:9E:D4:D8:DE:1F:01:66:DD

            X509v3 Subject Alternative Name: 
                DNS:pri-13buz6xe.vault.ca.42569264.consul, URI:spiffe://42569264-53e0-d4c3-6a58-2bf84d8b6ff1.consul
    Signature Algorithm: sha256WithRSAEncryption
         1c:ea:61:0d:6a:3c:0d:a1:82:51:7d:4b:9c:64:7c:ec:35:c7:
         af:99:e5:59:be:c7:f1:c7:88:df:ee:12:52:dc:1c:7b:e1:14:
         06:a3:ee:e7:c8:6a:5b:19:22:6f:bb:0e:3d:88:d6:27:e6:e5:
         48:96:fa:8d:b7:52:52:b4:93:fd:c5:9e:8f:1a:d2:22:aa:1e:
         be:60:f3:bf:3d:a8:90:cf:67:3e:13:39:62:b1:94:06:c2:45:
         33:65:55:c4:3c:d4:50:6a:bc:27:92:64:e4:63:7a:a6:e1:be:
         b5:42:c0:f5:13:23:66:a6:c2:63:a9:2a:d9:1f:4b:38:5a:55:
         4c:71:ce:e8:f3:77:a9:e9:90:62:5b:30:47:c0:3e:f9:9d:39:
         6d:a4:c6:42:b5:9a:c1:9f:2c:33:ab:fa:24:37:47:d3:8b:b9:
         53:86:76:a9:29:60:ed:63:6c:13:37:e6:c4:ab:a6:68:a2:b2:
         6d:a4:b3:d8:4d:d8:81:ee:f5:e4:f9:91:2c:48:12:03:80:ed:
         f4:35:6d:33:46:2b:6b:df:1d:3a:b9:f2:d8:e4:11:b0:10:3b:
         e7:c4:67:40:20:f5:3f:8a:19:cb:39:37:44:02:9d:52:ef:c5:
         90:b9:08:f8:64:9c:c0:77:98:af:8e:e7:26:f7:83:e0:12:1a:
         12:a1:dc:35

openssl crl2pkcs7 -nocrl -certfile secondary-inter.crt | openssl pkcs7 -print_certs -text -noout

Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            62:83:9b:71:fe:36:5f:1c:e0:f4:87:bc:3b:ae:b1:26:64:85:c2:e7
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN=pri-lfbisibt.vault.ca.42569264.consul
        Validity
            Not Before: Aug 16 20:51:28 2022 GMT
            Not After : Aug 16 20:51:58 2023 GMT
        Subject: 
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (256 bit)
                pub: 
                    04:67:28:27:86:9a:69:4b:97:61:92:b6:45:cc:b8:
                    e5:a7:2a:b8:48:3d:da:7d:72:bd:87:8f:94:4b:39:
                    40:f7:70:47:1e:7a:76:7e:a2:7c:1d:7a:ff:ca:79:
                    d6:ad:04:bd:ac:6f:f7:52:6a:d4:a8:e8:b0:d3:f8:
                    b3:20:1a:96:80
                ASN1 OID: prime256v1
                NIST CURVE: P-256
        X509v3 extensions:
            X509v3 Key Usage: critical
                Certificate Sign, CRL Sign
            X509v3 Basic Constraints: critical
                CA:TRUE, pathlen:0
            X509v3 Subject Key Identifier: 
                CA:60:EF:32:37:24:C2:49:6C:BD:2E:8A:9C:EC:89:8E:E9:B3:B6:DD
            X509v3 Authority Key Identifier: 
                keyid:55:F3:F6:79:BA:D8:6D:BE:BD:FE:A1:F1:9E:D4:D8:DE:1F:01:66:DD

            X509v3 Subject Alternative Name: critical
                URI:spiffe://42569264-53e0-d4c3-6a58-2bf84d8b6ff1.consul
    Signature Algorithm: sha256WithRSAEncryption
         80:4e:44:63:51:6f:92:74:55:55:df:d4:90:62:4e:03:4d:6d:
         79:3f:b9:92:c7:66:b3:25:cc:29:40:51:47:65:0c:30:ec:ad:
         ef:c2:dc:f0:d2:e8:44:46:60:6a:de:2c:b7:64:52:31:6b:cf:
         00:8e:09:f3:98:f0:c5:39:40:ba:6f:e5:14:af:de:72:e6:eb:
         74:0f:c9:ac:f7:b0:48:8b:54:04:9a:6e:d4:08:af:94:5a:07:
         e6:aa:03:cd:85:c7:12:bd:43:d3:c4:95:50:0d:8a:50:38:75:
         c1:eb:a8:93:4b:f9:bc:25:0b:14:b0:53:26:85:9d:54:bb:7b:
         2f:f8:df:94:38:68:4d:d9:11:c4:03:c8:c6:f1:ec:32:56:0d:
         af:7c:a3:e9:43:85:36:61:cb:e9:98:8f:45:40:ed:18:71:9a:
         e6:c0:2f:c8:8e:23:fd:b3:77:17:04:34:81:fb:7b:fa:58:24:
         91:74:5d:af:33:da:55:64:58:51:d1:77:cd:9c:47:2f:92:bd:
         90:e4:55:4b:42:74:6f:7e:a7:a7:fd:8c:a6:f8:7a:85:ac:92:
         3b:79:15:d5:99:70:24:b0:41:ed:5d:96:41:af:7f:67:e8:e9:
         83:a5:8d:3c:a5:02:c2:0a:af:7b:36:3a:4d:01:ec:17:80:63:
         ed:93:0b:a4

Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            4b:8d:f0:e4:e5:a0:3d:e3:70:22:66:15:d7:c2:11:be:75:1f:4b:23
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN=pri-lfbisibt.vault.ca.42569264.consul
        Validity
            Not Before: Aug 15 23:27:25 2022 GMT
            Not After : Aug 12 23:27:55 2032 GMT
        Subject: CN=pri-lfbisibt.vault.ca.42569264.consul
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:c6:c6:7e:fe:df:57:82:44:63:b8:fa:ab:6e:c4:
                    c9:bc:d2:fb:85:8b:be:f0:50:db:cd:f9:10:37:a4:
                    47:a0:3c:21:93:79:90:98:c1:f1:88:3b:8f:92:6c:
                    9f:03:3a:1d:63:8a:1f:5f:7d:ca:f0:df:75:03:ae:
                    19:e2:18:a4:ab:f6:54:4b:c4:f7:25:67:0c:82:54:
                    92:3b:d0:3e:45:29:65:9d:d1:45:1a:9f:f3:23:6e:
                    a7:cf:35:18:85:ca:c7:5f:31:d2:d2:90:5a:6a:f7:
                    17:d7:6a:24:3d:44:b7:c7:f0:50:39:a3:c5:e4:e6:
                    4a:fa:7f:1e:40:e8:60:57:94:c7:0a:06:ef:09:7e:
                    e5:d2:ae:af:e4:13:22:d8:b9:2b:b8:66:2f:0c:c5:
                    68:12:e0:6b:a9:3a:31:49:6a:59:54:5e:d3:85:20:
                    bf:87:fa:cf:91:42:12:d0:04:bc:86:ca:d3:88:df:
                    e8:40:d2:c9:cd:36:d3:bf:ae:2f:af:cd:a2:68:f5:
                    67:cb:d4:c0:4b:1b:06:8b:16:4d:5e:2e:53:5c:f7:
                    8f:64:b5:ff:79:15:39:69:0d:80:1e:e0:4e:0c:a9:
                    4c:b2:3c:17:a6:e0:7e:87:b2:5b:f2:bd:7a:0c:aa:
                    a6:66:0a:9e:fc:3c:16:3e:1e:3c:da:2f:03:4d:1f:
                    d4:8b
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Certificate Sign, CRL Sign
            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Subject Key Identifier: 
                55:F3:F6:79:BA:D8:6D:BE:BD:FE:A1:F1:9E:D4:D8:DE:1F:01:66:DD
            X509v3 Authority Key Identifier: 
                keyid:55:F3:F6:79:BA:D8:6D:BE:BD:FE:A1:F1:9E:D4:D8:DE:1F:01:66:DD

            X509v3 Subject Alternative Name: 
                DNS:pri-lfbisibt.vault.ca.42569264.consul, URI:spiffe://42569264-53e0-d4c3-6a58-2bf84d8b6ff1.consul
    Signature Algorithm: sha256WithRSAEncryption
         6e:57:a5:69:2e:b8:ec:d3:7d:ca:e5:90:73:e6:b4:56:df:1e:
         e3:b6:75:43:23:75:38:86:15:26:77:fd:2f:42:b2:32:9e:8e:
         8d:66:d9:8e:41:45:78:0e:3a:a8:c3:b4:cf:32:34:87:f6:1d:
         68:bf:8e:74:65:e6:61:e0:f9:5c:ad:f1:3d:83:bb:0d:d2:ba:
         a9:70:07:c3:f9:10:a4:ab:af:23:3f:3e:9a:ef:70:8f:07:bc:
         f5:bf:d9:50:2e:a8:ae:28:70:7b:00:ab:26:9a:6e:0f:ce:84:
         65:af:60:32:c6:09:bd:5c:68:6e:69:6b:e4:ae:0b:6e:1f:a6:
         10:a4:4e:28:f9:e4:f8:25:c1:99:f4:ac:cf:26:17:11:7a:1c:
         84:00:3d:51:29:d6:f0:6e:d8:46:1a:5e:61:d6:2c:45:91:cc:
         b5:c0:8f:e6:97:3d:bd:f9:71:41:fd:2b:69:3c:be:d7:73:c2:
         1f:6f:b3:17:8d:31:c6:cf:5d:de:04:96:f5:8c:c3:50:f6:d3:
         d9:d2:68:58:26:7b:0a:6a:2a:27:5c:00:f7:f0:ff:85:44:dd:
         15:fa:dc:af:dd:82:37:24:16:e6:90:51:11:d1:2e:8b:51:34:
         17:43:c4:15:3d:60:e2:44:f0:23:b6:2e:e8:a4:00:21:65:e8:
         e8:7f:b7:a7


```

```
The configuration change will trigger a root certificate rotation. 
An intermediate CA certificate is requested during rotation from the new root, which is then cross-signed by the old root and distributed alongside the newly generated leaf certificates.
The cross-signing provides a chain of trust back to the old root certificate. 
This ensures new certificates are accepted also by proxies that have not completed the update to the new CA and avoids disruptions.
```