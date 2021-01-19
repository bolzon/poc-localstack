# POC with localstack

## 🌪 🌧 🌩

This project is a proof of concept using localstack as a mock AWS (cloud) to build a basic data ingestion infra using Terraform.

## Execution

Run localstack.

```sh
$ docker-compose up -d
```

Create the infra.

```sh
$ terraform init
$ terraform plan
$ terraform apply
```

## License

📖&nbsp; [MIT](./LICENSE)
