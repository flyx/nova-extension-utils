{ lib, basePath, config, configWorkspace }:
let
  escaped = builtins.replaceStrings [ "." ] [ "_" ];
  processConfigItem = jsPath: path: workspace: value:
    let fieldPath = "${jsPath}.${escaped value.name}";
    in if value.type == "section" then
      "\n    ${fieldPath} = {};"
      + (processConfigItems fieldPath "${path}.${value.name}" workspace value.children)
    else
      "\n    ${fieldPath} = new ConfigItem(\"${path}.${value.name}\", ${
        if workspace then "ConfigItem.workspaceOnly" else
        if (if value ? noWorkspace then value.noWorkspace else false) then "ConfigItem.globalOnly" else "0"
      });";
  processConfigItems = jsPath: path: workspace: items:
    lib.concatStrings
    (builtins.map (processConfigItem jsPath path workspace) items);
in ''
  // autogenerated by nova-extension-utils

  const ConfigItem = require("config-item.js").ConfigItem;

  class Config {
    constructor() {${processConfigItems "this" basePath false config}${processConfigItems "this" basePath true configWorkspace}
    }
  }

  exports.Config = Config;
''
