from flask import Flask, Blueprint
from routes import RoutesBP
import vars

app = Flask(__name__)

if __name__ == "__main__":
    app.register_blueprint(RoutesBP)
    app.run(host=vars.HOST, port=vars.PORT, debug=vars.DEBUG)
