# Golang Demo

## Build binary

```sh
GOOS=linux GOARCH=amd64 go build -o golang-demo
chmod +x golang-demo
```

## Preconditions

1. Install and configure PostreSQL db
2. Create schema from file `db_schema.sql`

## Start program

```sh
DB_ENDPOINT=<db_endpoint> DB_PORT=5432 DB_USER=<user> DB_PASS=<password> DB_NAME=<db_name> ./golang-demo
```

## Use program examples

```sh
curl "http://localhost:8080/ping?url=https://google.com" --header "Content-Type:application/text"
curl -X POST "http://localhost:8080/video?id=1&title=Forest_Gump"
curl "http://localhost:8080/videos"
curl "http://localhost:8080/fibonacci?number=7"
curl "http://localhost:8080/memory-leak"
```

## Helm charts usage

1. Firstly, duplicate the `secret.yaml.template` file, change the values to the desired and save it as `secret.yaml`
2. (If running minikube) Run `eval $(minikube docker-env)` to change docker path to local minikube's registry
3. (If running minicube) In root dir, run `minikube image build -t yhvd11/silly-demo:latest .` to build the container
4. (If NOT running on minikube) remove `imagePullPolicy: Never` from `helm-charts/go-deployment.yaml`
