{
  lib,
  python3,
  ...
}:
with python3.pkgs;
  buildPythonApplication rec {
    pname = "my_cookies";
    version = "0.1.3";

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-3e5j0HFOXUyUo6YVUKQnbaxvAUtDoRTzGqW8HUfzrQ8=";
    };

    propagatedBuildInputs = [
      setuptools
      browser-cookie3
    ];

    # No tests included
    doCheck = false;
    pythonImportsCheck = ["my_cookies"];

    meta = with lib; {
      homepage = "https://github.com/kaiwk/my_cookies";
      description = "This package is used for retrieve leetcode cookies from Chrome with local keyring.";
      license = licenses.mit;
      maintainers = with tensorfiles.maintainers; [czichy];
    };
  }
