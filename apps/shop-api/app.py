import os
import socket

from flask import Flask, jsonify

app = Flask(__name__)


@app.get("/")
def index():
    return jsonify(
        service="shop-api",
        version=os.environ.get("APP_VERSION", "dev"),
        hostname=socket.gethostname(),
    )


@app.get("/health")
def health():
    return jsonify(status="ok")
