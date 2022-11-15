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
  
  constructor(key) {
    this.key = key;
    nova.config.onDidChange(key, this.changedGlobal, this);
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
    return wsVal === null ? nova.config.get(this.key) : wsVal;
  }
}

exports.ConfigItem = ConfigItem;