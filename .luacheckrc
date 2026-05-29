std = "lua51+luajit"
ignore = {
  "212",  -- unused argument
  "213",  -- unused loop variable
}
files["spec/"] = { std = "+busted" }
