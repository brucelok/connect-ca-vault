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

3. Create Vault token for above policy and save the Token

```
 # vault token create -policy=connect-ca
```

4. Update the Token in `./consul/server.hcl` for Consul-dc1 server and then start then docker

```
docker compose up consul-dc1 -d
```

5. Verify the Consul is using Vault as CA provider, and check the Token value.
```
# consul connect ca get-config
```

6. Update the Token in `./consul-dc2/server.hcl` for Consul-dc2 server and then start then docker
```
docker compose up consul-dc2 -d
```

2. Verify if two servers are successfully federated
```
# consul members -wan
```
