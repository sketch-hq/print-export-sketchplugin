const { Orientation, Unit } = require('./enums')
const { getFilename, valueWithPropertyPath } = require('./utils')
const Settings = require('sketch/settings')
const { ExportType, Scope } = require('./enums')
const { paperSizeStandards } = require('./constants')
const OptionsDialog = require('./options-dialog')
const { getSelectedDocument } = require('sketch/dom')
const path = require('path')

const mainClassName = 'PEPrintExport'
const pluginName = 'Print Export'
const settingsKey = {
  exportType: 'exportType',
  scope: 'scope',
  showArtboardShadow: 'showArtboardShadow',
  showArtboardName: 'showArtboardName',
  showPrototypingLinks: 'showPrototypingLinks',
  pageSizeStandardName: 'paperSizeStandardName',
  pageSizeName: 'pageSizeName',
  orientation: 'orientation',
  pageWidth: 'pageWidth',
  pageHeight: 'pageHeight',
  includeCropMarks: 'includeCropMarks',
  bleed: 'bleed',
  slug: 'slug'
}
const defaultValues = {
  exportType: ExportType.SketchPagePerPage,
  scope: Scope.CurrentPage,
  showArtboardShadow: true,
  showArtboardName: true,
  showPrototypingLinks: true,
  paperSizeStandardIndex: 0,
  orientation: Orientation.Portrait,
  includeCropMarks: false,
  bleed: 0,
  slug: 0
}

export default function(context) {
  const document = getSelectedDocument()
  const optionsDialog = new OptionsDialog(pluginName, getSettings(document), context)
  if (optionsDialog.dialog.runModal() === NSAlertFirstButtonReturn) {
    setSettings(optionsDialog, document)
    const filePath = getFilePath(optionsDialog.scope, document)
    if (filePath != null) {
      const options = {
        exportType: optionsDialog.exportType,
        scope: optionsDialog.scope,
        showArtboardShadow: optionsDialog.showArtboardShadow,
        showArtboardName: optionsDialog.showArtboardName,
        showPrototypingLinks: optionsDialog.showPrototypingLinks,
        pageWidth: normalizeDimension(optionsDialog.pageWidth, optionsDialog.paperSizeStandard),
        pageHeight: normalizeDimension(optionsDialog.pageHeight, optionsDialog.paperSizeStandard),
        includeCropMarks: optionsDialog.includeCropMarks,
        bleed: normalizeDimension(optionsDialog.bleed, optionsDialog.paperSizeStandard),
        slug: normalizeDimension(optionsDialog.slug, optionsDialog.paperSizeStandard)
      }
      frameworkClass().generatePDFWithDocument_filePath_options_context(document.sketchObject, filePath, options, context)
    }
  }
}

export const onShutdown = function(context) {
  frameworkClass().onShutdown(context)
}

const frameworkClass = function() {
  return require('./framework/print-export.xcworkspace/contents.xcworkspacedata').getClass(mainClassName)
}

const getSettings = function(document) {
  const settings = {}
  settings.exportType = getSetting(settingsKey.exportType, document)
  settings.scope = getSetting(settingsKey.scope, document)
  settings.showArtboardShadow = getSetting(settingsKey.showArtboardShadow, document)
  settings.showArtboardName = getSetting(settingsKey.showArtboardName, document)
  settings.showPrototypingLinks = getSetting(settingsKey.showPrototypingLinks, document)
  settings.paperSizeStandardName = getSetting(settingsKey.pageSizeStandardName, document, paperSizeStandards[defaultValues.paperSizeStandardIndex].name)
  const paperSizeStandard = paperSizeStandards.find(paperSizeStandard => paperSizeStandard.name === settings.paperSizeStandardName)
  settings.pageSizeName = getSetting(settingsKey.pageSizeName, document, getDefaultPageSize(paperSizeStandard).name)
  const paperSize = paperSizeStandard.sizes.find(paperSize => paperSize.name === settings.pageSizeName)
  settings.orientation = getSetting(settingsKey.orientation,  document)
  settings.pageWidth = getSetting(settingsKey.pageWidth, document, (settings.orientation === Orientation.Portrait ? paperSize.width : paperSize.height))
  settings.pageHeight = getSetting(settingsKey.pageHeight, document, (settings.orientation === Orientation.Portrait ? paperSize.height : paperSize.width))
  settings.includeCropMarks = getSetting(settingsKey.includeCropMarks, document)
  settings.bleed = getSetting(settingsKey.bleed, document)
  settings.slug = getSetting(settingsKey.slug, document)
  return settings
}

const getSetting = function(key, document, defaultValue = undefined) {
  let value = Settings.documentSettingForKey(document, key)
  if (value !== undefined) {
    return value;
  }
  value = Settings.settingForKey(key)
  if (value !== undefined) {
    return value;
  }
  if (defaultValue !== undefined) {
    return defaultValue
  }
  return defaultValues[key]
}

const setSettings = function(optionsDialog, document) {
  const properties = {
    [settingsKey.pageSizeStandardName]: 'paperSizeStandard.name',
    [settingsKey.pageSizeName]: 'pageSize.name'
  }
  for (let prop in settingsKey) {
    if (settingsKey.hasOwnProperty(prop)) {
      const key = settingsKey[prop]
      const optionsDialogProperty = properties[key] || key
      const value = valueWithPropertyPath(optionsDialog, optionsDialogProperty)
      Settings.setDocumentSettingForKey(document, key, value)
      Settings.setSettingForKey(key, value)
    }
  }
}

const getFilePath = function(scope, document) {
  const panel = NSSavePanel.savePanel()
  panel.canChooseFiles = true
  panel.canChooseDirectories = false
  panel.allowsMultipleSelection = false
  panel.message = 'Enter the filename of the PDF'
  panel.prompt = 'Export'
  panel.allowedFileTypes = ['pdf']
  switch (scope) {
    case Scope.CurrentPage:
      panel.nameFieldStringValue = Settings.documentSettingForKey(document, 'filename') || `${document.selectedPage.name}.pdf`
      break;

    case Scope.AllPages: {
      panel.nameFieldStringValue =   Settings.documentSettingForKey(document, 'filename') || getFilename(decodeURIComponent(document.path), '.pdf') || 'Untitled.pdf'
      break;
    }
  }
  if (panel.runModal() === NSModalResponseOK) {
    const filePath = panel.URL().path()
    Settings.setDocumentSettingForKey(document, 'filename', path.basename(filePath))
    return filePath
  } else {
    return null
  }
}

const normalizeDimension = function(dimension, paperSizeStandard) {
  switch (paperSizeStandard.unit) {
    case Unit.Millimeter:
      return dimension

    case Unit.Inch:
      return dimension * 25.4
  }
}

const getDefaultPageSize = function(paperSizeStandard) {
  const pageSize = paperSizeStandard.sizes.find(pageSize => pageSize.default)
  if (pageSize) {
    return pageSize
  } else {
    return paperSizeStandard.sizes[0]
  }
}
