/** Frozen SOP status contract (see integration/STATUS_MAP.md). */

const STATUS = {
  ACC: 'ACC',
  PKU: 'PKU',
  ARR: 'ARR',
  SRT: 'SRT',
  SHB: 'SHB',
  HUB: 'HUB',
  GWD: 'GWD',
  OFD: 'OFD',
  DRS: 'DRS',
  POD: 'POD',
  UND: 'UND',
  OVN: 'OVN',
  SCF: 'SCF',
  RTN: 'RTN',
  N13: 'N13',
  N12: 'N12',
  N9: 'N9',
  BDE: 'BDE',
};

/** Map API scan → t_consignment.cn_status (null = do not change CN status). */
const TO_CN_STATUS = {
  ACC: null,
  PKU: 'INB',
  ARR: 'INB',
  GWD: 'INB',
  SRT: 'SHB',
  SHB: 'SHB',
  HUB: 'SHB',
  OFD: 'OFD',
  DRS: 'DRS',
  POD: 'POD',
  UND: 'UND',
  OVN: 'UND',
  SCF: 'SHB',
  RTN: 'RTS',
  N13: 'UTL',
  N12: 'UND',
  N9: 'UND',
  BDE: 'BDE',
};

/** Customer-facing labels (web tracking). */
const CUSTOMER_LABEL = {
  BDE: 'Pending Pickup',
  ACC: 'Pending Pickup',
  PKU: 'Collected',
  ARR: 'In Transit',
  GWD: 'In Transit',
  SRT: 'In Transit',
  HUB: 'In Transit',
  SHB: 'To Be Delivered',
  OFD: 'To Be Delivered',
  DRS: 'To Be Delivered',
  SCF: 'To Be Delivered',
  POD: 'Signed / Delivered',
  PCC: 'Signed / Delivered',
  PFP: 'Signed / Delivered',
  PCB: 'Signed / Delivered',
  UND: 'Problematic / Delayed',
  OVN: 'Problematic / Delayed',
  N13: 'Problematic / Delayed',
  N12: 'Problematic / Delayed',
  N9: 'Problematic / Delayed',
  RTN: 'Returning to Sender',
  RTS: 'Returning to Sender',
  UTL: 'Problematic / Delayed',
  INB: 'In Transit',
  MNF: 'In Transit',
};

const PIPELINE = [
  STATUS.ACC,
  STATUS.PKU,
  STATUS.ARR,
  STATUS.SRT,
  STATUS.SHB,
  STATUS.OFD,
  STATUS.DRS,
  STATUS.POD,
  STATUS.UND,
];

const TRACK_STATUS_LIST = [
  'ACC',
  'PKU',
  'ARR',
  'SRT',
  'SHB',
  'HUB',
  'GWD',
  'OFD',
  'DRS',
  'POD',
  'UND',
  'OVN',
  'SCF',
  'RTN',
  'N13',
  'N12',
  'N9',
  'BDE',
];

function customerLabelOf(code) {
  if (!code) return 'Pending Pickup';
  const key = String(code).trim().toUpperCase();
  return CUSTOMER_LABEL[key] || 'In Transit';
}

/** Detailed timeline text, e.g. "Parcel arrived at SBH325 hub". */
function detailLabelOf(code, locId, note) {
  const key = String(code || '')
    .trim()
    .toUpperCase();
  const hub = String(locId || '')
    .trim()
    .toUpperCase();
  const atHub = hub ? ` at ${hub} hub` : ' at hub';
  const from = hub ? ` from ${hub}` : '';
  const via = hub ? ` via ${hub}` : '';
  const paren = hub ? ` (${hub})` : '';

  let detail;
  switch (key) {
    case 'BDE':
      detail = 'Order created — waiting for pickup';
      break;
    case 'ACC':
      detail = hub
        ? `Parcel assigned to courier at ${hub}`
        : 'Parcel assigned to courier';
      break;
    case 'PKU':
      detail = hub
        ? `Parcel collected from seller (${hub})`
        : 'Parcel collected from seller';
      break;
    case 'GWD':
      detail = hub
        ? `Parcel departed gateway (${hub})`
        : 'Parcel departed gateway';
      break;
    case 'ARR':
    case 'INB':
      detail = `Parcel arrived${atHub}`;
      break;
    case 'SRT':
    case 'MNF':
      detail = hub
        ? `Parcel sorting at ${hub} hub`
        : 'Parcel sorting at hub';
      break;
    case 'HUB':
      detail = `Parcel handed over${atHub}`;
      break;
    case 'SHB':
      detail = hub
        ? `Parcel received by storekeeper at ${hub}`
        : 'Parcel received by storekeeper';
      break;
    case 'OFD':
      detail = `Parcel out for delivery${from}`;
      break;
    case 'DRS':
      detail = hub
        ? `Parcel with courier for delivery (${hub})`
        : 'Parcel with courier for delivery';
      break;
    case 'SCF':
      detail = hub
        ? `Parcel ready for self-collection at ${hub}`
        : 'Parcel ready for self-collection';
      break;
    case 'POD':
    case 'PCC':
    case 'PFP':
    case 'PCB':
      detail = `Parcel delivered and signed${paren}`;
      break;
    case 'UND':
    case 'OVN':
      detail = hub
        ? `Delivery attempt failed at ${hub}`
        : 'Delivery attempt failed';
      break;
    case 'RTN':
    case 'RTS':
      detail = `Parcel returning to sender${via}`;
      break;
    case 'N13':
    case 'UTL':
      detail = 'Parcel delayed — location update pending';
      break;
    case 'N12':
    case 'N9':
      detail = 'Parcel reported damaged';
      break;
    default:
      detail = customerLabelOf(key);
  }

  const noteText = String(note || '').trim();
  if (
    noteText &&
    !detail.toLowerCase().includes(noteText.toLowerCase()) &&
    !/^(ops:|ops desk|scanned via|mobile demo|driver scan)/i.test(noteText)
  ) {
    detail += ` — ${noteText}`;
  }
  return detail;
}

function isTerminalDelivered(code) {
  return ['POD', 'PCC', 'PFP', 'PCB'].includes(String(code || '').toUpperCase());
}

/**
 * Sprint 1 pipeline + legacy pickup/delivery compatibility.
 * @param {string} jobType pickup|delivery|pipeline
 * @param {string|null} fromApiStatus last mobile/ops scan
 * @param {string} toStatus next scan
 */
function isAllowedTransition(jobType, fromApiStatus, toStatus) {
  const from = fromApiStatus ? String(fromApiStatus).toUpperCase() : null;
  const to = String(toStatus).toUpperCase();

  if (!Object.values(STATUS).includes(to) && to !== 'BDE') {
    return false;
  }

  // Always allow first assignment accept
  if (to === STATUS.ACC) return true;

  // Happy-path pipeline (ops + driver)
  const pipelineNext = {
    null: [STATUS.ACC, STATUS.PKU, STATUS.BDE],
    BDE: [STATUS.ACC, STATUS.PKU],
    ACC: [STATUS.PKU],
    PKU: [STATUS.ARR, STATUS.HUB, STATUS.GWD],
    GWD: [STATUS.ARR],
    ARR: [STATUS.SRT, STATUS.SHB],
    SRT: [STATUS.SHB, STATUS.OFD, STATUS.DRS],
    SHB: [STATUS.OFD, STATUS.DRS, STATUS.SCF],
    HUB: [STATUS.SRT, STATUS.SHB, STATUS.OFD, STATUS.DRS],
    OFD: [STATUS.POD, STATUS.UND, STATUS.OVN, STATUS.DRS],
    DRS: [STATUS.POD, STATUS.UND, STATUS.OVN, STATUS.OFD],
    UND: [STATUS.OVN, STATUS.OFD, STATUS.DRS, STATUS.RTN],
    OVN: [STATUS.OFD, STATUS.DRS, STATUS.SCF, STATUS.RTN],
    SCF: [STATUS.POD, STATUS.RTN],
  };

  const allowed = pipelineNext[from] || pipelineNext.null;
  if (allowed.includes(to)) return true;

  // Legacy pickup-only path
  if (jobType === 'pickup') {
    if (to === STATUS.PKU) return !from || from === STATUS.ACC || from === STATUS.BDE;
    if (to === STATUS.HUB) return from === STATUS.PKU || from === STATUS.ACC;
    return false;
  }

  // Legacy delivery-only path
  if (jobType === 'delivery') {
    if (to === STATUS.DRS || to === STATUS.OFD) {
      return (
        !from ||
        ['ACC', 'PKU', 'ARR', 'SRT', 'SHB', 'HUB', 'OFD', 'DRS', 'OVN', 'UND'].includes(
          from,
        )
      );
    }
    if (to === STATUS.POD || to === STATUS.UND) {
      return !from || from === STATUS.DRS || from === STATUS.OFD;
    }
  }

  return false;
}

/** Next allowed scans for UI hints. */
function nextAllowedScans(fromApiStatus) {
  const from = fromApiStatus ? String(fromApiStatus).toUpperCase() : null;
  const pipelineNext = {
    null: [STATUS.ACC, STATUS.PKU],
    BDE: [STATUS.ACC, STATUS.PKU],
    ACC: [STATUS.PKU],
    PKU: [STATUS.ARR, STATUS.HUB],
    ARR: [STATUS.SRT, STATUS.SHB],
    SRT: [STATUS.SHB, STATUS.OFD],
    SHB: [STATUS.OFD, STATUS.DRS],
    HUB: [STATUS.SRT, STATUS.SHB, STATUS.OFD],
    OFD: [STATUS.POD, STATUS.UND],
    DRS: [STATUS.POD, STATUS.UND],
    UND: [STATUS.OFD, STATUS.OVN],
    OVN: [STATUS.OFD],
    SCF: [STATUS.POD],
    POD: [],
  };
  return pipelineNext[from] || pipelineNext.null;
}

module.exports = {
  STATUS,
  TO_CN_STATUS,
  CUSTOMER_LABEL,
  PIPELINE,
  TRACK_STATUS_LIST,
  customerLabelOf,
  detailLabelOf,
  isTerminalDelivered,
  isAllowedTransition,
  nextAllowedScans,
};
