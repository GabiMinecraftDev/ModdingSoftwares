from flask import Blueprint, render_template

RoutesBP = Blueprint('Routes', __name__)

@RoutesBP.route ("/")
def main():
    return render_template("Main.html")

@RoutesBP.route ("/download")
def download():
    return render_template("Download.html")

# @RoutesBP.route ("/Help")
# def help():
#     return render_template("Help.html")

@RoutesBP.route ("/Dependencies")
def dependencies():
    return render_template("Dependencies.html")

@RoutesBP.route ("/Developers")
def developers():
    return render_template("Developers.html")
