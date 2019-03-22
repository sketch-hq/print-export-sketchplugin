const { loadNib, buildDialog } = require('./utils')
const { ExportType, Scope, Orientation, Unit } = require('./enums')
const { paperSizeStandards } = require('./constants')

const UNIT_TEXTFIELD_INDENTIFIERS = ['pageWidthUnits', 'pageHeightUnits', 'bleedUnits', 'slugUnits'];

module.exports = class OptionsDialog {

  constructor(pluginName, model, context) {
    this.nib = loadNib('PEOptionsAccessoryView')

    const exportTypeHandler = function() {}
    this.nib.artboardPerPage.setCOSJSTargetFunction(exportTypeHandler)
    this.nib.sketchPagePerPage.setCOSJSTargetFunction(exportTypeHandler)
    switch (model.exportType) {
      case ExportType.ArtboardPerPage:
        this.nib.artboardPerPage.state = NSOnState
        break;

      case ExportType.SketchPagePerPage:
        this.nib.sketchPagePerPage.state = NSOnState
        break;
    }

    const scopeHandler = function() {}
    this.nib.exportCurrentPage.setCOSJSTargetFunction(scopeHandler)
    this.nib.exportAllPages.setCOSJSTargetFunction(scopeHandler)
    switch (model.scope) {
      case Scope.CurrentPage:
        this.nib.exportCurrentPage.state = NSOnState
        break;

      case Scope.AllPages:
        this.nib.exportAllPages.state = NSOnState
        break;
    }

    let currentPaperSizeStandard
    for (let [index, paperSizeStandard] of paperSizeStandards.entries()) {
      this.nib.paperSizeStandard.addItemWithTitle(paperSizeStandard.name)
      if (model.paperSizeStandardName === paperSizeStandard.name) {
        this.nib.paperSizeStandard.selectItemAtIndex(index)
        currentPaperSizeStandard = paperSizeStandard
      }
    }
    this.updateUnits(currentPaperSizeStandard)
    this.paperSizeStandardChanged = this.paperSizeStandardChanged.bind(this)
    this.nib.paperSizeStandard.setCOSJSTargetFunction(this.paperSizeStandardChanged)

    this.populatePageSizes(this.nib.pageSize, currentPaperSizeStandard, model.pageSizeName)
    this.pageSizeChanged = this.pageSizeChanged.bind(this)
    this.nib.pageSize.setCOSJSTargetFunction(this.pageSizeChanged)

    this.nib.pageWidth.doubleValue = model.pageWidth
    this.nib.pageHeight.doubleValue = model.pageHeight

    this.orientationChanged = this.orientationChanged.bind(this)
    this.nib.portrait.setCOSJSTargetFunction(this.orientationChanged)
    this.nib.landscape.setCOSJSTargetFunction(this.orientationChanged)
    switch (model.orientation) {
      case Orientation.Portrait:
        this.nib.portrait.state = NSOnState
        break;

      case Orientation.Landscape:
        this.nib.landscape.state = NSOnState
        break;
    }

    this.nib.includeCropMarks.state = model.includeCropMarks ? NSOnState : NSOffState

    this.nib.bleed.doubleValue = model.bleed
    this.nib.slug.doubleValue = model.slug

    this.dialog = buildDialog(pluginName, 'Export', this.nib.rootView, context)
  }

  paperSizeStandardChanged(sender) {
    const pageSizeStandard = paperSizeStandards[sender.indexOfSelectedItem()]
    this.populatePageSizes(this.nib.pageSize, pageSizeStandard)
    this.pageSizeChanged()
    this.updateUnits(pageSizeStandard)
  }

  pageSizeChanged() {
    const pageSize = this.pageSize
    let width, height
    switch (this.orientation) {
      case Orientation.Portrait:
        width = pageSize.width
        height = pageSize.height
        break

      case Orientation.Landscape:
        width = pageSize.height
        height = pageSize.width
        break
    }
    this.nib.pageWidth.doubleValue = width
    this.nib.pageHeight.doubleValue = height
  }

  orientationChanged() {
    const width = this.nib.pageWidth.doubleValue()
    const height = this.nib.pageHeight.doubleValue()
    this.nib.pageWidth.doubleValue = height
    this.nib.pageHeight.doubleValue = width
  }

  populatePageSizes(pageSizePopUpButton, paperSizeStandard, pageSizeName = undefined) {
    pageSizePopUpButton.removeAllItems()
    for (let [index, pageSize] of paperSizeStandard.sizes.entries()) {
      pageSizePopUpButton.addItemWithTitle(pageSize.name)
      if (pageSizeName === pageSize.name) {
        pageSizePopUpButton.selectItemAtIndex(index)
      }
    }
  }

  updateUnits(pageSizeStandard) {
    UNIT_TEXTFIELD_INDENTIFIERS.forEach(identifier => {
      const textField = this.nib[identifier]
      switch (pageSizeStandard.unit) {
        case Unit.Millimeter:
          textField.stringValue = 'mm'
          break;

        case Unit.Inch:
          textField.stringValue = 'inch'
          break;
      }
    })
  }

  get exportType() {
    return this.nib.artboardPerPage.state() === NSOnState ? ExportType.ArtboardPerPage : ExportType.SketchPagePerPage
  }

  get scope() {
    return this.nib.exportCurrentPage.state() === NSOnState ? Scope.CurrentPage : Scope.AllPages
  }

  get paperSizeStandard() {
    return paperSizeStandards[this.nib.paperSizeStandard.indexOfSelectedItem()]
  }

  get pageSize() {
    return this.paperSizeStandard.sizes[this.nib.pageSize.indexOfSelectedItem()]
  }

  get orientation() {
    return this.nib.portrait.state() === NSOnState ? Orientation.Portrait : Orientation.Landscape
  }

  get pageWidth() {
    return this.nib.pageWidth.doubleValue()
  }

  get pageHeight() {
    return this.nib.pageHeight.doubleValue()
  }

  get includeCropMarks() {
    return this.nib.includeCropMarks.state() === NSOnState
  }

  get bleed() {
    return this.nib.bleed.doubleValue()
  }

  get slug() {
    return this.nib.slug.doubleValue()
  }

}