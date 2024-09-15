{...}: {
  modules.system.users.usersSettings."root" = {
    agenixPassword.enable = true;
    uid = 0;
    gid = 0;
  };
}
