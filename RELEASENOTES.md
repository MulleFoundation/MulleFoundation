## 0.23.0






* **BREAKING**: rename MulleObjCLoader+MulleFoundation -> MulleObjCDeps+MulleFoundation (headers and implementations); callers must update references to the loader API
* remove mulle-foundation-standalone entrypoint and switch reflection include to objc-deps.inc to centralize dependency generation
