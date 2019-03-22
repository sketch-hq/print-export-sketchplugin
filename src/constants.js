const { Unit } = require('./enums')

export const paperSizeStandards = [
  {
    name: 'A',
    unit: Unit.Millimeter,
    sizes: [
      {
        name: 'A0',
        width: 841,
        height: 1189
      },
      {
        name: 'A1',
        width: 593,
        height: 841
      },
      {
        name: 'A2',
        width: 420,
        height: 594
      },
      {
        name: 'A3',
        width: 297,
        height: 420
      },
      {
        name: 'A4',
        width: 210,
        height: 297,
        default: true
      },
      {
        name: 'A5',
        width: 148,
        height: 210
      }
    ]
  },
  {
    name: 'US',
    unit: Unit.Inch,
    sizes: [
      {
        name: 'Letter',
        width: 8.5,
        height: 11
      },
      {
        name: 'Legal',
        width: 8.5,
        height: 14
      },
      {
        name: 'Tabloid',
        width: 11,
        height: 17
      },
      {
        name: 'Ledger',
        width: 17,
        height: 11
      },
      {
        name: 'Junior Legal',
        width: 5,
        height: 8
      },
      {
        name: 'Half Letter',
        width: 5.5,
        height: 8.5
      }
    ]
  }
]