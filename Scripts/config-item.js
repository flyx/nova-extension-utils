// configuration support
// part of nova-extension-utils

/// a config item that can be set globally and overridden per workspace.
/// has a listener interface that fires when the resulting value changes.
class ConfigItem {
  changedGlobal(newVal, oldVal) {
    if (this.callback) this.callback.call(this.callbackThis, newVal, oldVal);
  }
  
  changedWorkspace(newVal, oldVal) {
    if (this.callback) this.callback.call(this.callbackThis, newVal, oldVal);
  }
  
  constructor(key, workspaceOnly) {
    this.key = key;
    this.workspaceOnly = workspaceOnly;
    if (!workspaceOnly) nova.config.onDidChange(key, this.changedGlobal, this);
    nova.workspace.config.onDidChange(key, this.changedWorkspace, this);
  }
  
  onDidChange(callback, thisValue) {
    this.callback = callback;
    this.callbackThis = thisValue;
  }
  
  observe(callback, thisValue) {
    this.onDidChange(callback, thisValue);
    this.callback.call(this.callbackThis, this.value(), this.value());
  }
  
  value() {
    const wsVal = nova.workspace.config.get(this.key);
    return (wsVal === null && !this.workspaceOnly) ? nova.config.get(this.key) : wsVal;
  }
  
  /// This is an abstraction over ConfigItem and literal values.
  /// It is used in places where an API expects either a literal value or
  /// a ConfigItem. It resolves ConfigItems to their current value,
  /// recurses into arrays, and returns other values as-is.
  static process(item, defaultValue) {
    if (item instanceof ConfigItem) {
      return item.value();
    } else if (item instanceof Array) {
      return item.map(ConfigItem.process);
    } else if (typeof item === "undefined" || item === null) {
      return defaultValue ?? item;
    } else return item;
  }
  
  /// Registers the given callback with item if it's a ConfigItem, or
  /// with any inner ConfigItems if item is an array.
  /// Does nothing for non-ConfigItem items.
  static registerChangeListener(item, callback, thisValue) {
    if (item instanceof ConfigItem) {
      item.onDidChange(callback, thisValue);
    } else if (item instanceof Array) {
      for (const inner of item) {
        ConfigItem.registerChangeListener(inner, () => callback.call(thisValue, this.value()));
      }
    }
  }
}

exports.ConfigItem = ConfigItem;