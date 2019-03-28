# Print Export Plugin

Exports artboards to a CMYK PDF which can then be printed. Each page in the PDF document can contain all the artboards in a page or just one artboard. 

## Installation
 
### From a release (simplest)
 
- [Download](https://github.com/skpm/print-export-sketchplugin/releases/latest) the latest release of the plugin
- Double-click the .zip file to extract the plugin
- Double-click `print-export.sketchplugin` to install the plugin
 
### From source
 
- You will need to have [XCode](https://itunes.apple.com/app/xcode/id497799835?mt=12) installed
- Clone the repo
- Install the dependencies with `npm install`

## Usage

- Open the Sketch file you want to generate a PDF from and then go to _Plugins > Print Export_.
- Specify your options and press Continue
- Then specify a filename and location of the PDF file and press Export

In the options dialog you can specify bleed and slug. Bleed is the area beyond the trimmed page while slug is the area beyond the bleed which contains the crop marks. If you don't want to include either you can enter 0. The size of the page specified is the size of the trimmed area.

