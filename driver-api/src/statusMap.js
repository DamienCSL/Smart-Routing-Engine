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
  ACC: 'Courier Assigned',
  PKU: 'Collected',
  ARR: 'Arrived at Hub',
  GWD: 'In Transit',
  SRT: 'Sorting',
  HUB: 'At Hub',
  SHB: 'Preparing for Delivery',
  OFD: 'Out for Delivery',
  DRS: 'Out for Delivery',
  SCF: 'Ready for Self-Collection',
  POD: 'Delivered',
  PCC: 'Delivered',
  PFP: 'Delivered',
  PCB: 'Delivered',
  UND: 'Delivery Unsuccessful',
  OVN: 'Delivery Delayed',
  N13: 'Delivery Delayed',
  N12: 'Delivery Delayed',
  N9: 'Delivery Delayed',
  RTN: 'Returning to Sender',
  RTS: 'Returning to Sender',
  UTL: 'Delivery Delayed',
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

function friendlyPlace(locId) {
  const loc = String(locId || '')
    .trim()
    .toUpperCase();
  if (!loc) return '';
  const known = {
    BKI: 'Kota Kinabalu',
    KUL: 'Kota Kinabalu',
    SDK: 'Sandakan',
    TWU: 'Tawau',
    SBH325: 'Kota Kinabalu receiving hub',
    SBH326: 'Kota Kinabalu delivery station',
    805: 'Kota Kinabalu sorting centre',
    'SDK-ST1': 'Sandakan station',
    'TWU-ST1': 'Tawau station',
  };
  return known[loc] || loc;
}

/** Customer timeline sentence (no ops jargon / internal notes). */
function detailLabelOf(code, locId) {
  const key = String(code || '')
    .trim()
    .toUpperCase();
  const place = friendlyPlace(locId);
  const at = place ? ` at our ${place}` : '';
  const from = place ? ` from ${place}` : '';
  const inPlace = place ? ` in ${place}` : '';

  switch (key) {
    case 'BDE':
      return 'Your order has been created and is waiting for pickup';
    case 'ACC':
      return 'A courier has been assigned to pick up your parcel';
    case 'PKU':
      return place
        ? `Your parcel has been collected from the sender${inPlace}`
        : 'Your parcel has been collected from the sender';
    case 'GWD':
      return place
        ? `Your parcel has left our gateway facility${inPlace}`
        : 'Your parcel is on the way to the next facility';
    case 'ARR':
    case 'INB':
      return place
        ? `Your parcel has arrived${at}`
        : 'Your parcel has arrived at our hub';
    case 'SRT':
    case 'MNF':
      return place
        ? `Your parcel is being sorted${at}`
        : 'Your parcel is being sorted at our hub';
    case 'HUB':
      return place
        ? `Your parcel has been received${at}`
        : 'Your parcel has been received at our hub';
    case 'SHB':
      return place
        ? `Your parcel is at our ${place} and is being prepared for delivery`
        : 'Your parcel is being prepared for delivery at our hub';
    case 'OFD':
      return place
        ? `Your parcel is out for delivery${from}`
        : 'Your parcel is out for delivery';
    case 'DRS':
      return 'Your parcel is with the courier for delivery';
    case 'SCF':
      return place
        ? `Your parcel is ready for self-collection${at}`
        : 'Your parcel is ready for self-collection';
    case 'POD':
    case 'PCC':
    case 'PFP':
    case 'PCB':
      return 'Your parcel has been delivered successfully';
    case 'UND':
    case 'OVN':
      return place
        ? `Delivery was unsuccessful${inPlace} — we will try again`
        : 'Delivery was unsuccessful — we will try again';
    case 'RTN':
    case 'RTS':
      return 'Your parcel is being returned to the sender';
    case 'N13':
    case 'UTL':
      return 'Your parcel is delayed — we are updating the location';
    case 'N12':
    case 'N9':
      return 'There is an issue with your parcel — our team is following up';
    case 'CAN':
      return 'This order has been cancelled';
    default:
      return customerLabelOf(key);
  }
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
