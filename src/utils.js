const ObjClass = require('cocoascript-class').default;
const manifest = require('./manifest.json')
const path = require('path')

export function loadNib(nibName, delegate = undefined) {
  const bundle = NSBundle.bundleWithIdentifier(manifest.identifier)
  const nibOwner = (new ObjClass(delegate || {})).new()
  const topLevelObjectsPointer = MOPointer.alloc().initWithValue(null)
  const loadedNib = bundle.loadNibNamed_owner_topLevelObjects(nibName, nibOwner, topLevelObjectsPointer)
  if (!loadedNib) {
    throw new Error(`Error loading nib file ${nibName}.nib`)
  }

  let rootView
  var topLevelObjects = topLevelObjectsPointer.value();
  for (let i = 0; i < topLevelObjects.count(); i++) {
    let obj = topLevelObjects.objectAtIndex(i)
    if (/View$/.test(String(obj.className()))) {
      rootView = obj
      break
    }
  }

  const result = {nibOwner, rootView}

  walkViewTree(rootView, function(view) {
    const id = String(view.identifier())
    if (id && !id.startsWith('_')) {
      result[id] = view
    }
  })

  return result
}

export function buildDialog(dialogTitle, buttonTitle, accessoryView, context) {
  const dialog = NSAlert.new()
  dialog.messageText = dialogTitle
  dialog.icon = NSImage.alloc().initByReferencingFile(context.plugin.urlForResourceNamed('icon.png').path())
  dialog.accessoryView = accessoryView
  dialog.addButtonWithTitle(buttonTitle)
  dialog.addButtonWithTitle('Cancel')
  return dialog
}

export function loadFramework(framework, frameworkClassName, context) {
  const frameworkPath = context.scriptPath.stringByDeletingLastPathComponent().stringByDeletingLastPathComponent().stringByAppendingPathComponent("Resources")
  if (!frameworkLoaded(frameworkClassName) && !Mocha.sharedRuntime().loadFrameworkWithName_inDirectory(framework, frameworkPath)) {
    console.error(`Couldn't load framework ${framework}`)
    return false
  }
  return true
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

const frameworkLoaded = function(frameworkClassName) {
  return NSClassFromString(frameworkClassName) != null
}

const walkViewTree = function(rootView, fn) {
  function _visit(view) {
    fn(view)

    const subviews = view.subviews();
    for (let i = 0; i < subviews.count(); i++) {
      _visit(subviews.objectAtIndex(i))
    }
  }

  _visit(rootView);
}