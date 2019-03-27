const { Orientation, Unit } = require('./enums')
const { loadFramework, getFilename, valueWithPropertyPath } = require('./utils')
const Settings = require('sketch/settings')
const { ExportType, Scope } = require('./enums')
const { paperSizeStandards } = require('./constants')
const OptionsDialog = require('./options-dialog')
const { getSelectedDocument } = require('sketch/dom')
const UI = require('sketch/ui')

const MAIN_CLASS_NAME = 'PEPrintExport'
const PLUGIN_NAME = 'Print Export'
const SETTINGS_KEY = {
  EXPORT_TYPE: 'exportType',
  SCOPE: 'scope',
  SHOW_ARTBOARD_SHADOW: 'showArtboardShadow',
  SHOW_ARTBOARD_NAME: 'showArtboardName',
  SHOW_PROTOTYPING_LINKS: 'showPrototypingLinks',
  PAPER_SIZE_STANDARD_NAME: 'paperSizeStandardName',
  PAGE_SIZE_NAME: 'pageSizeName',
  ORIENTATION: 'orientation',
  PAGE_WIDTH: 'pageWidth',
  PAGE_HEIGHT: 'pageHeight',
  INCLUDE_CROP_MARKS: 'includeCropMarks',
  BLEED: 'bleed',
  SLUG: 'slug'
}

export default function(context) {
  if (loadFramework('print_export', MAIN_CLASS_NAME, context)) {
    const document = getSelectedDocument()
    const optionsDialog = new OptionsDialog(PLUGIN_NAME, getSettings(document), context)
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
}

export const onShutdown = function(context) {
  frameworkClass().onShutdown(context)
}

const frameworkClass = function() {
  return NSClassFromString(MAIN_CLASS_NAME)
}

const getSettings = function(document) {
  const settings = {}
  settings.exportType = Settings.documentSettingForKey(document, SETTINGS_KEY.EXPORT_TYPE) || Settings.settingForKey(SETTINGS_KEY.EXPORT_TYPE)
    || ExportType.ArtboardPerPage
  settings.scope = Settings.documentSettingForKey(document, SETTINGS_KEY.SCOPE) || Settings.settingForKey(SETTINGS_KEY.SCOPE) || Scope.CurrentPage
  settings.showArtboardShadow = Settings.documentSettingForKey(document, SETTINGS_KEY.SHOW_ARTBOARD_SHADOW) || Settings.settingForKey(SETTINGS_KEY.SHOW_ARTBOARD_SHADOW) || true
  settings.showArtboardName = Settings.documentSettingForKey(document, SETTINGS_KEY.SHOW_ARTBOARD_NAME) || Settings.settingForKey(SETTINGS_KEY.SHOW_ARTBOARD_NAME) || false
  settings.showPrototypingLinks = Settings.documentSettingForKey(document, SETTINGS_KEY.SHOW_PROTOTYPING_LINKS) || Settings.settingForKey(SETTINGS_KEY.SHOW_PROTOTYPING_LINKS) || true
  settings.paperSizeStandardName = Settings.documentSettingForKey(document, SETTINGS_KEY.PAPER_SIZE_STANDARD_NAME)
    || Settings.settingForKey(SETTINGS_KEY.PAPER_SIZE_STANDARD_NAME) || paperSizeStandards[0].name
  const paperSizeStandard = paperSizeStandards.find(paperSizeStandard => paperSizeStandard.name === settings.paperSizeStandardName)
  settings.pageSizeName = Settings.documentSettingForKey(document, SETTINGS_KEY.PAGE_SIZE_NAME) || Settings.settingForKey(SETTINGS_KEY.PAGE_SIZE_NAME)
    || getDefaultPageSize(paperSizeStandard).name
  const paperSize = paperSizeStandard.sizes.find(paperSize => paperSize.name === settings.pageSizeName)
  settings.orientation = Settings.documentSettingForKey(document, SETTINGS_KEY.ORIENTATION) || Settings.settingForKey(SETTINGS_KEY.ORIENTATION)
    || Orientation.Portrait
  settings.pageWidth = Settings.documentSettingForKey(document, SETTINGS_KEY.PAGE_WIDTH) || Settings.settingForKey(SETTINGS_KEY.PAGE_WIDTH)
    || (settings.orientation === Orientation.Portrait ? paperSize.width : paperSize.height)
  settings.pageHeight = Settings.documentSettingForKey(document, SETTINGS_KEY.PAGE_HEIGHT) || Settings.settingForKey(SETTINGS_KEY.PAGE_HEIGHT)
    || (settings.orientation === Orientation.Portrait ? paperSize.height : paperSize.width)
  settings.includeCropMarks = Settings.documentSettingForKey(document, SETTINGS_KEY.INCLUDE_CROP_MARKS) !== undefined
    || Settings.settingForKey(SETTINGS_KEY.INCLUDE_CROP_MARKS) !== undefined || true
  settings.bleed = Settings.documentSettingForKey(document, SETTINGS_KEY.BLEED)
  if (settings.bleed === undefined) {
    settings.bleed = Settings.settingForKey(SETTINGS_KEY.BLEED)
  }
  if (settings.bleed === undefined) {
    settings.bleed = 0
  }
  settings.slug = Settings.documentSettingForKey(document, SETTINGS_KEY.SLUG)
  if (settings.slug === undefined) {
    settings.slug = Settings.settingForKey(SETTINGS_KEY.SLUG)
  }
  if (settings.slug === undefined) {
    settings.slug = 0
  }
  return settings
}

const setSettings = function(optionsDialog, document) {
  const properties = {
    [SETTINGS_KEY.PAPER_SIZE_STANDARD_NAME]: 'paperSizeStandard.name',
    [SETTINGS_KEY.PAGE_SIZE_NAME]: 'pageSize.name'
  }
  for (let prop in SETTINGS_KEY) {
    if (SETTINGS_KEY.hasOwnProperty(prop)) {
      const settingsKey = SETTINGS_KEY[prop]
      const optionsDialogProperty = properties[settingsKey] || settingsKey
      const value = valueWithPropertyPath(optionsDialog, optionsDialogProperty)
      Settings.setDocumentSettingForKey(document, settingsKey, value)
      Settings.setSettingForKey(settingsKey, value)
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
    const path = panel.URL().path()
    Settings.setDocumentSettingForKey(document, 'filename', getFilename(path))
    return path
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


