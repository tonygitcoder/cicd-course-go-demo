FROM golang:1.23-alpine

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY *.go ./

RUN go build -o golang-demo

EXPOSE 8080

CMD ["./golang-demo"]
