{pkgs, ...}: {
  force = true;
  default = "google";
  order = [
    "bing"
    "ddg"
    "google"
  ];
}
