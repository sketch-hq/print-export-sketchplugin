const ObjClass = require('cocoascript-class').default;
const manifest = require('./manifest.json')
const path = require('path')

export function buildDialog(dialogTitle, buttonTitle, accessoryView, context) {
  const dialog = NSAlert.new()
  dialog.messageText = dialogTitle
  dialog.icon = NSImage.alloc().initByReferencingFile(context.plugin.urlForResourceNamed('icon.png').path())
  dialog.accessoryView = accessoryView
  dialog.addButtonWithTitle(buttonTitle)
  dialog.addButtonWithTitle('Cancel')
  return dialog
}

export function getFilename(filePath, extension) {
  return `${path.basename(filePath, path.extname(filePath))}${extension}`
}

export function valueWithPropertyPath(object, keyPath) {
  const keys = keyPath.split('.')
  let currentObject = object
  keys.forEach(key => {
    currentObject = currentObject[key]
  })
  return currentObject
}
