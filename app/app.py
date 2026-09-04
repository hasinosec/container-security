"""Minimal health-check API used as the subject of the container-hardening case study.

The app itself is intentionally trivial — the point of this project is the
Dockerfile and image, not the application logic.
"""

from flask import Flask, jsonify

app = Flask(__name__)


@app.get("/health")
def health():
    return jsonify(status="ok")


@app.get("/")
def index():
    return jsonify(service="container-security demo", endpoints=["/health"])


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
