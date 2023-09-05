# Open VSCode Server with Custom Dev Environment and Auth Proxy

## Overview

This repository contains demo code to set up an Open VSCode Server with a custom development environment, wrapped with an authentication proxy written in Go. This project is intended for demonstration purposes and is not recommended for production use.

## Prerequisites

- Docker

## Getting Started

### Build the Docker Image

```bash
docker build -t custom-vscode-server .
```

### Run the Auth Proxy

Edit create an config.env file from config.env-example, and set your username and password. After starting a vscode server, run

```bash
cd ./proxy
./start.sh
```

### Access the Open VSCode Server

Open your web browser and navigate to `http://localhost:port`.

## Components

### Docker File

The Docker file sets up the Open VSCode Server along with a custom development environment. It installs XYZ, sets up ABC, and does PQR.

### Auth Proxy

The authentication proxy is written in Go and serves as a protective layer in front of the Open VSCode Server. It performs basic authentication checks.

## Configuration

Explain any configuration files or environment variables that need to be set.

## Limitations

Since this is demo code, there are several limitations:

- Not optimized for production
- Limited security features

## Contributing

This is a demo project, and contributions are not actively sought. However, if you find a bug or have a feature request, feel free to open an issue.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.
