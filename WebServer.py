from flask import Flask, Blueprint
from routes import RoutesBP
import vars

app = Flask(__name__)

app.register_blueprint(RoutesBP)

if __name__ == "__main__":
    app.run(host=vars.HOST, port=vars.PORT, debug=vars.DEBUG)