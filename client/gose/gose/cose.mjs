import * as $bit_array from "../../gleam_stdlib/gleam/bit_array.mjs";
import * as $bool from "../../gleam_stdlib/gleam/bool.mjs";
import * as $int from "../../gleam_stdlib/gleam/int.mjs";
import * as $list from "../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../gleam_stdlib/gleam/result.mjs";
import * as $string from "../../gleam_stdlib/gleam/string.mjs";
import * as $crypto from "../../kryptos/kryptos/crypto.mjs";
import * as $ec from "../../kryptos/kryptos/ec.mjs";
import * as $eddsa from "../../kryptos/kryptos/eddsa.mjs";
import * as $rsa from "../../kryptos/kryptos/rsa.mjs";
import * as $xdh from "../../kryptos/kryptos/xdh.mjs";
import {
  Ok,
  Error,
  toList,
  Empty as $Empty,
  List$Empty$const as $List$Empty$const,
  prepend as listPrepend,
  CustomType as $CustomType,
  makeError,
  toBitArray,
} from "../gleam.mjs";
import * as $gose from "../gose.mjs";
import * as $cbor from "../gose/cbor.mjs";
import * as $utils from "../gose/internal/utils.mjs";

const FILEPATH = "src/gose/cose.gleam";

export class TextPlain extends $CustomType {}
export const ContentType$TextPlain$const = new TextPlain();
export const ContentType$TextPlain = () => ContentType$TextPlain$const;
export const ContentType$isTextPlain = (value) => value instanceof TextPlain;

export class OctetStream extends $CustomType {}
export const ContentType$OctetStream$const = new OctetStream();
export const ContentType$OctetStream = () => ContentType$OctetStream$const;
export const ContentType$isOctetStream = (value) =>
  value instanceof OctetStream;

export class Json extends $CustomType {}
export const ContentType$Json$const = new Json();
export const ContentType$Json = () => ContentType$Json$const;
export const ContentType$isJson = (value) => value instanceof Json;

export class Cbor extends $CustomType {}
export const ContentType$Cbor$const = new Cbor();
export const ContentType$Cbor = () => ContentType$Cbor$const;
export const ContentType$isCbor = (value) => value instanceof Cbor;

export class Cwt extends $CustomType {}
export const ContentType$Cwt$const = new Cwt();
export const ContentType$Cwt = () => ContentType$Cwt$const;
export const ContentType$isCwt = (value) => value instanceof Cwt;

export class CoseSign extends $CustomType {}
export const ContentType$CoseSign$const = new CoseSign();
export const ContentType$CoseSign = () => ContentType$CoseSign$const;
export const ContentType$isCoseSign = (value) => value instanceof CoseSign;

export class CoseSign1 extends $CustomType {}
export const ContentType$CoseSign1$const = new CoseSign1();
export const ContentType$CoseSign1 = () => ContentType$CoseSign1$const;
export const ContentType$isCoseSign1 = (value) => value instanceof CoseSign1;

export class CoseEncrypt extends $CustomType {}
export const ContentType$CoseEncrypt$const = new CoseEncrypt();
export const ContentType$CoseEncrypt = () => ContentType$CoseEncrypt$const;
export const ContentType$isCoseEncrypt = (value) =>
  value instanceof CoseEncrypt;

export class CoseEncrypt0 extends $CustomType {}
export const ContentType$CoseEncrypt0$const = new CoseEncrypt0();
export const ContentType$CoseEncrypt0 = () => ContentType$CoseEncrypt0$const;
export const ContentType$isCoseEncrypt0 = (value) =>
  value instanceof CoseEncrypt0;

export class CoseMac extends $CustomType {}
export const ContentType$CoseMac$const = new CoseMac();
export const ContentType$CoseMac = () => ContentType$CoseMac$const;
export const ContentType$isCoseMac = (value) => value instanceof CoseMac;

export class CoseMac0 extends $CustomType {}
export const ContentType$CoseMac0$const = new CoseMac0();
export const ContentType$CoseMac0 = () => ContentType$CoseMac0$const;
export const ContentType$isCoseMac0 = (value) => value instanceof CoseMac0;

export class CoseKey extends $CustomType {}
export const ContentType$CoseKey$const = new CoseKey();
export const ContentType$CoseKey = () => ContentType$CoseKey$const;
export const ContentType$isCoseKey = (value) => value instanceof CoseKey;

export class CoseKeySet extends $CustomType {}
export const ContentType$CoseKeySet$const = new CoseKeySet();
export const ContentType$CoseKeySet = () => ContentType$CoseKeySet$const;
export const ContentType$isCoseKeySet = (value) => value instanceof CoseKeySet;

export class IntContentType extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const ContentType$IntContentType = ($0) => new IntContentType($0);
export const ContentType$isIntContentType = (value) =>
  value instanceof IntContentType;
export const ContentType$IntContentType$0 = (value) => value[0];

export class TextContentType extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const ContentType$TextContentType = ($0) => new TextContentType($0);
export const ContentType$isTextContentType = (value) =>
  value instanceof TextContentType;
export const ContentType$TextContentType$0 = (value) => value[0];

export class Alg extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const Header$Alg = ($0) => new Alg($0);
export const Header$isAlg = (value) => value instanceof Alg;
export const Header$Alg$0 = (value) => value[0];

export class Crit extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const Header$Crit = ($0) => new Crit($0);
export const Header$isCrit = (value) => value instanceof Crit;
export const Header$Crit$0 = (value) => value[0];

export class ContentType extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const Header$ContentType = ($0) => new ContentType($0);
export const Header$isContentType = (value) => value instanceof ContentType;
export const Header$ContentType$0 = (value) => value[0];

export class Kid extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const Header$Kid = ($0) => new Kid($0);
export const Header$isKid = (value) => value instanceof Kid;
export const Header$Kid$0 = (value) => value[0];

export class Iv extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const Header$Iv = ($0) => new Iv($0);
export const Header$isIv = (value) => value instanceof Iv;
export const Header$Iv$0 = (value) => value[0];

export class PartialIv extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const Header$PartialIv = ($0) => new PartialIv($0);
export const Header$isPartialIv = (value) => value instanceof PartialIv;
export const Header$PartialIv$0 = (value) => value[0];

export class Unknown extends $CustomType {
  constructor($0, $1) {
    super();
    this[0] = $0;
    this[1] = $1;
  }
}
export const Header$Unknown = ($0, $1) => new Unknown($0, $1);
export const Header$isUnknown = (value) => value instanceof Unknown;
export const Header$Unknown$0 = (value) => value[0];
export const Header$Unknown$1 = (value) => value[1];

function is_alg(header) {
  if (header instanceof Alg) {
    return true;
  } else {
    return false;
  }
}

/**
 * Extract the algorithm identifier (label 1).
 */
export function algorithm(headers) {
  let $ = $list.find(headers, is_alg);
  if ($ instanceof Ok) {
    let $1 = $[0];
    if ($1 instanceof Alg) {
      let id = $1[0];
      return new Ok(id);
    } else {
      return new Error(new $gose.ParseError("missing header label 1 (alg)"));
    }
  } else {
    return new Error(new $gose.ParseError("missing header label 1 (alg)"));
  }
}

function is_crit(header) {
  if (header instanceof Crit) {
    return true;
  } else {
    return false;
  }
}

/**
 * Extract the critical headers list (label 2).
 */
export function critical(headers) {
  let $ = $list.find(headers, is_crit);
  if ($ instanceof Ok) {
    let $1 = $[0];
    if ($1 instanceof Crit) {
      let labels = $1[0];
      return new Ok(labels);
    } else {
      return new Error(new $gose.ParseError("missing header label 2 (crit)"));
    }
  } else {
    return new Error(new $gose.ParseError("missing header label 2 (crit)"));
  }
}

function is_content_type(header) {
  if (header instanceof ContentType) {
    return true;
  } else {
    return false;
  }
}

/**
 * Extract the content type (label 3).
 */
export function content_type(headers) {
  let $ = $list.find(headers, is_content_type);
  if ($ instanceof Ok) {
    let $1 = $[0];
    if ($1 instanceof ContentType) {
      let ct = $1[0];
      return new Ok(ct);
    } else {
      return new Error(
        new $gose.ParseError("missing header label 3 (content type)"),
      );
    }
  } else {
    return new Error(
      new $gose.ParseError("missing header label 3 (content type)"),
    );
  }
}

function is_kid(header) {
  if (header instanceof Kid) {
    return true;
  } else {
    return false;
  }
}

/**
 * Extract the key ID (label 4).
 */
export function kid(headers) {
  let $ = $list.find(headers, is_kid);
  if ($ instanceof Ok) {
    let $1 = $[0];
    if ($1 instanceof Kid) {
      let k = $1[0];
      return new Ok(k);
    } else {
      return new Error(new $gose.ParseError("missing header label 4 (kid)"));
    }
  } else {
    return new Error(new $gose.ParseError("missing header label 4 (kid)"));
  }
}

function is_iv(header) {
  if (header instanceof Iv) {
    return true;
  } else {
    return false;
  }
}

/**
 * Extract the IV (label 5).
 */
export function iv(headers) {
  let $ = $list.find(headers, is_iv);
  if ($ instanceof Ok) {
    let $1 = $[0];
    if ($1 instanceof Iv) {
      let v = $1[0];
      return new Ok(v);
    } else {
      return new Error(new $gose.ParseError("missing header label 5 (IV)"));
    }
  } else {
    return new Error(new $gose.ParseError("missing header label 5 (IV)"));
  }
}

function is_partial_iv(header) {
  if (header instanceof PartialIv) {
    return true;
  } else {
    return false;
  }
}

/**
 * Extract the partial IV (label 6).
 */
export function partial_iv(headers) {
  let $ = $list.find(headers, is_partial_iv);
  if ($ instanceof Ok) {
    let $1 = $[0];
    if ($1 instanceof PartialIv) {
      let v = $1[0];
      return new Ok(v);
    } else {
      return new Error(
        new $gose.ParseError("missing header label 6 (Partial IV)"),
      );
    }
  } else {
    return new Error(
      new $gose.ParseError("missing header label 6 (Partial IV)"),
    );
  }
}

export function content_type_to_cbor(ct) {
  if (ct instanceof TextPlain) {
    return new $cbor.Int(0);
  } else if (ct instanceof OctetStream) {
    return new $cbor.Int(42);
  } else if (ct instanceof Json) {
    return new $cbor.Int(50);
  } else if (ct instanceof Cbor) {
    return new $cbor.Int(60);
  } else if (ct instanceof Cwt) {
    return new $cbor.Int(61);
  } else if (ct instanceof CoseSign) {
    return new $cbor.Int(101);
  } else if (ct instanceof CoseSign1) {
    return new $cbor.Int(102);
  } else if (ct instanceof CoseEncrypt) {
    return new $cbor.Int(103);
  } else if (ct instanceof CoseEncrypt0) {
    return new $cbor.Int(104);
  } else if (ct instanceof CoseMac) {
    return new $cbor.Int(105);
  } else if (ct instanceof CoseMac0) {
    return new $cbor.Int(106);
  } else if (ct instanceof CoseKey) {
    return new $cbor.Int(10_001);
  } else if (ct instanceof CoseKeySet) {
    return new $cbor.Int(10_002);
  } else if (ct instanceof IntContentType) {
    let n = ct[0];
    return new $cbor.Int(n);
  } else {
    let s = ct[0];
    return new $cbor.Text(s);
  }
}

export function header_to_cbor(header) {
  if (header instanceof Alg) {
    let id = header[0];
    return [new $cbor.Int(1), new $cbor.Int(id)];
  } else if (header instanceof Crit) {
    let labels = header[0];
    return [
      new $cbor.Int(2),
      new $cbor.Array(
        $list.map(labels, (var0) => { return new $cbor.Int(var0); }),
      ),
    ];
  } else if (header instanceof ContentType) {
    let ct = header[0];
    return [new $cbor.Int(3), content_type_to_cbor(ct)];
  } else if (header instanceof Kid) {
    let k = header[0];
    return [new $cbor.Int(4), new $cbor.Bytes(k)];
  } else if (header instanceof Iv) {
    let v = header[0];
    return [new $cbor.Int(5), new $cbor.Bytes(v)];
  } else if (header instanceof PartialIv) {
    let v = header[0];
    return [new $cbor.Int(6), new $cbor.Bytes(v)];
  } else {
    let key = header[0];
    let value = header[1];
    return [key, value];
  }
}

function content_type_from_cbor(value) {
  if (value instanceof $cbor.Int) {
    let $ = value[0];
    if ($ === 0) {
      return new Ok(ContentType$TextPlain$const);
    } else if ($ === 42) {
      return new Ok(ContentType$OctetStream$const);
    } else if ($ === 50) {
      return new Ok(ContentType$Json$const);
    } else if ($ === 60) {
      return new Ok(ContentType$Cbor$const);
    } else if ($ === 61) {
      return new Ok(ContentType$Cwt$const);
    } else if ($ === 101) {
      return new Ok(ContentType$CoseSign$const);
    } else if ($ === 102) {
      return new Ok(ContentType$CoseSign1$const);
    } else if ($ === 103) {
      return new Ok(ContentType$CoseEncrypt$const);
    } else if ($ === 104) {
      return new Ok(ContentType$CoseEncrypt0$const);
    } else if ($ === 105) {
      return new Ok(ContentType$CoseMac$const);
    } else if ($ === 106) {
      return new Ok(ContentType$CoseMac0$const);
    } else if ($ === 10001) {
      return new Ok(ContentType$CoseKey$const);
    } else if ($ === 10002) {
      return new Ok(ContentType$CoseKeySet$const);
    } else {
      let n = $;
      return new Ok(new IntContentType(n));
    }
  } else if (value instanceof $cbor.Text) {
    let s = value[0];
    return new Ok(new TextContentType(s));
  } else {
    return new Error(
      new $gose.ParseError(
        "header label 3 (content type): expected Int or Text",
      ),
    );
  }
}

function parse_int_list(loop$values, loop$acc) {
  while (true) {
    let values = loop$values;
    let acc = loop$acc;
    if (values instanceof $Empty) {
      return new Ok($list.reverse(acc));
    } else {
      let $ = values.head;
      if ($ instanceof $cbor.Int) {
        let rest = values.tail;
        let n = $[0];
        loop$values = rest;
        loop$acc = listPrepend(n, acc);
      } else {
        return new Error(
          new $gose.ParseError("header label 2 (crit): expected array of Int"),
        );
      }
    }
  }
}

export function header_from_cbor(pair) {
  let $ = pair[0];
  if ($ instanceof $cbor.Int) {
    let $1 = pair[1];
    if ($1 instanceof $cbor.Int) {
      let $2 = $[0];
      if ($2 === 1) {
        let id = $1[0];
        return new Ok(new Alg(id));
      } else if ($2 === 2) {
        return new Error(
          new $gose.ParseError("header label 2 (crit): expected Array"),
        );
      } else if ($2 === 3) {
        let value = $1;
        return $result.map(
          content_type_from_cbor(value),
          (ct) => { return new ContentType(ct); },
        );
      } else if ($2 === 4) {
        return new Error(
          new $gose.ParseError("header label 4 (kid): expected Bytes"),
        );
      } else if ($2 === 5) {
        return new Error(
          new $gose.ParseError("header label 5 (IV): expected Bytes"),
        );
      } else if ($2 === 6) {
        return new Error(
          new $gose.ParseError("header label 6 (Partial IV): expected Bytes"),
        );
      } else {
        let key = $;
        let value = $1;
        return new Ok(new Unknown(key, value));
      }
    } else if ($1 instanceof $cbor.Bytes) {
      let $2 = $[0];
      if ($2 === 1) {
        return new Error(
          new $gose.ParseError("header label 1 (alg): expected Int"),
        );
      } else if ($2 === 2) {
        return new Error(
          new $gose.ParseError("header label 2 (crit): expected Array"),
        );
      } else if ($2 === 3) {
        let value = $1;
        return $result.map(
          content_type_from_cbor(value),
          (ct) => { return new ContentType(ct); },
        );
      } else if ($2 === 4) {
        let k = $1[0];
        return new Ok(new Kid(k));
      } else if ($2 === 5) {
        let v = $1[0];
        return new Ok(new Iv(v));
      } else if ($2 === 6) {
        let v = $1[0];
        return new Ok(new PartialIv(v));
      } else {
        let key = $;
        let value = $1;
        return new Ok(new Unknown(key, value));
      }
    } else if ($1 instanceof $cbor.Array) {
      let $2 = $[0];
      if ($2 === 1) {
        return new Error(
          new $gose.ParseError("header label 1 (alg): expected Int"),
        );
      } else if ($2 === 2) {
        let values = $1[0];
        return $result.map(
          parse_int_list(values, $List$Empty$const),
          (labels) => { return new Crit(labels); },
        );
      } else if ($2 === 3) {
        let value = $1;
        return $result.map(
          content_type_from_cbor(value),
          (ct) => { return new ContentType(ct); },
        );
      } else if ($2 === 4) {
        return new Error(
          new $gose.ParseError("header label 4 (kid): expected Bytes"),
        );
      } else if ($2 === 5) {
        return new Error(
          new $gose.ParseError("header label 5 (IV): expected Bytes"),
        );
      } else if ($2 === 6) {
        return new Error(
          new $gose.ParseError("header label 6 (Partial IV): expected Bytes"),
        );
      } else {
        let key = $;
        let value = $1;
        return new Ok(new Unknown(key, value));
      }
    } else {
      let $2 = $[0];
      if ($2 === 1) {
        return new Error(
          new $gose.ParseError("header label 1 (alg): expected Int"),
        );
      } else if ($2 === 2) {
        return new Error(
          new $gose.ParseError("header label 2 (crit): expected Array"),
        );
      } else if ($2 === 3) {
        let value = $1;
        return $result.map(
          content_type_from_cbor(value),
          (ct) => { return new ContentType(ct); },
        );
      } else if ($2 === 4) {
        return new Error(
          new $gose.ParseError("header label 4 (kid): expected Bytes"),
        );
      } else if ($2 === 5) {
        return new Error(
          new $gose.ParseError("header label 5 (IV): expected Bytes"),
        );
      } else if ($2 === 6) {
        return new Error(
          new $gose.ParseError("header label 6 (Partial IV): expected Bytes"),
        );
      } else {
        let key = $;
        let value = $1;
        return new Ok(new Unknown(key, value));
      }
    }
  } else {
    let key = $;
    let value = pair[1];
    return new Ok(new Unknown(key, value));
  }
}

export function headers_from_cbor(pairs) {
  return $list.try_map(pairs, header_from_cbor);
}

export function headers_to_cbor(headers) {
  return $list.map(headers, header_to_cbor);
}

function key_op_to_cose(op) {
  if (op instanceof $gose.Sign) {
    return 1;
  } else if (op instanceof $gose.Verify) {
    return 2;
  } else if (op instanceof $gose.Encrypt) {
    return 3;
  } else if (op instanceof $gose.Decrypt) {
    return 4;
  } else if (op instanceof $gose.WrapKey) {
    return 5;
  } else if (op instanceof $gose.UnwrapKey) {
    return 6;
  } else if (op instanceof $gose.DeriveKey) {
    return 7;
  } else {
    return 8;
  }
}

/**
 * Convert a content encryption algorithm to its COSE integer identifier.
 *
 * Some content encryption algorithms are JOSE-only and have no COSE
 * identifier, in which case this returns an error.
 */
export function content_alg_to_int(alg) {
  if (alg instanceof $gose.AesGcm) {
    let $ = alg[0];
    if ($ instanceof $gose.Aes128) {
      return new Ok(1);
    } else if ($ instanceof $gose.Aes192) {
      return new Ok(2);
    } else {
      return new Ok(3);
    }
  } else if (alg instanceof $gose.AesCbcHmac) {
    return new Error(
      new $gose.InvalidState(
        "no COSE identifier for algorithm: " + $string.inspect(alg),
      ),
    );
  } else if (alg instanceof $gose.ChaCha20Poly1305) {
    return new Ok(24);
  } else {
    return new Error(
      new $gose.InvalidState(
        "no COSE identifier for algorithm: " + $string.inspect(alg),
      ),
    );
  }
}

/**
 * Convert a key encryption algorithm to its COSE integer identifier.
 *
 * Some key encryption algorithms are JOSE-only and have no COSE
 * identifier, in which case this returns an error.
 */
export function key_encryption_alg_to_int(alg) {
  if (alg instanceof $gose.Direct) {
    return new Ok(-6);
  } else if (alg instanceof $gose.AesKeyWrap) {
    let $ = alg[0];
    if ($ instanceof $gose.AesKw) {
      let $1 = alg[1];
      if ($1 instanceof $gose.Aes128) {
        return new Ok(-3);
      } else if ($1 instanceof $gose.Aes192) {
        return new Ok(-4);
      } else {
        return new Ok(-5);
      }
    } else {
      return new Error(
        new $gose.InvalidState(
          "no COSE identifier for algorithm: " + $string.inspect(alg),
        ),
      );
    }
  } else if (alg instanceof $gose.ChaCha20KeyWrap) {
    return new Error(
      new $gose.InvalidState(
        "no COSE identifier for algorithm: " + $string.inspect(alg),
      ),
    );
  } else if (alg instanceof $gose.RsaEncryption) {
    let $ = alg[0];
    if ($ instanceof $gose.RsaPkcs1v15) {
      return new Error(
        new $gose.InvalidState(
          "no COSE identifier for algorithm: " + $string.inspect(alg),
        ),
      );
    } else if ($ instanceof $gose.RsaOaepSha1) {
      return new Ok(-40);
    } else {
      return new Ok(-41);
    }
  } else if (alg instanceof $gose.EcdhEs) {
    let $ = alg[0];
    if ($ instanceof $gose.EcdhEsDirect) {
      return new Ok(-25);
    } else if ($ instanceof $gose.EcdhEsAesKw) {
      let $1 = $[0];
      if ($1 instanceof $gose.Aes128) {
        return new Ok(-29);
      } else if ($1 instanceof $gose.Aes192) {
        return new Ok(-30);
      } else {
        return new Ok(-31);
      }
    } else {
      return new Error(
        new $gose.InvalidState(
          "no COSE identifier for algorithm: " + $string.inspect(alg),
        ),
      );
    }
  } else {
    return new Error(
      new $gose.InvalidState(
        "no COSE identifier for algorithm: " + $string.inspect(alg),
      ),
    );
  }
}

/**
 * Convert a MAC algorithm to its COSE integer identifier.
 */
export function mac_alg_to_int(alg) {
  let $ = alg[0];
  if ($ instanceof $gose.HmacSha256) {
    return 5;
  } else if ($ instanceof $gose.HmacSha384) {
    return 6;
  } else {
    return 7;
  }
}

/**
 * Convert a signature algorithm to its COSE integer identifier.
 */
export function signature_alg_to_int(alg) {
  if (alg instanceof $gose.RsaPkcs1) {
    let $ = alg[0];
    if ($ instanceof $gose.RsaPkcs1Sha256) {
      return -257;
    } else if ($ instanceof $gose.RsaPkcs1Sha384) {
      return -258;
    } else {
      return -259;
    }
  } else if (alg instanceof $gose.RsaPss) {
    let $ = alg[0];
    if ($ instanceof $gose.RsaPssSha256) {
      return -37;
    } else if ($ instanceof $gose.RsaPssSha384) {
      return -38;
    } else {
      return -39;
    }
  } else if (alg instanceof $gose.Ecdsa) {
    let $ = alg[0];
    if ($ instanceof $gose.EcdsaP256) {
      return -7;
    } else if ($ instanceof $gose.EcdsaP384) {
      return -35;
    } else if ($ instanceof $gose.EcdsaP521) {
      return -36;
    } else {
      return -47;
    }
  } else {
    return -8;
  }
}

/**
 * Convert a signing algorithm to its COSE integer identifier.
 */
export function signing_alg_to_int(alg) {
  if (alg instanceof $gose.DigitalSignature) {
    let sig_alg = alg[0];
    return signature_alg_to_int(sig_alg);
  } else {
    let mac_alg = alg[0];
    return mac_alg_to_int(mac_alg);
  }
}

function encode_alg_metadata(alg) {
  if (alg instanceof $gose.SigningAlg) {
    let signing_alg = alg[0];
    return new Ok(
      toList([
        [new $cbor.Int(3), new $cbor.Int(signing_alg_to_int(signing_alg))],
      ]),
    );
  } else if (alg instanceof $gose.KeyEncryptionAlg) {
    let ke_alg = alg[0];
    return $result.map(
      key_encryption_alg_to_int(ke_alg),
      (id) => { return toList([[new $cbor.Int(3), new $cbor.Int(id)]]); },
    );
  } else {
    let content_alg = alg[0];
    return $result.map(
      content_alg_to_int(content_alg),
      (id) => { return toList([[new $cbor.Int(3), new $cbor.Int(id)]]); },
    );
  }
}

function resolve_alg_metadata(k) {
  let $ = $gose.alg(k);
  if ($ instanceof Ok) {
    let alg = $[0];
    return encode_alg_metadata(alg);
  } else {
    return new Ok($List$Empty$const);
  }
}

function encode_metadata(k) {
  let _block;
  let $ = $gose.kid(k);
  if ($ instanceof Ok) {
    let kid$1 = $[0];
    _block = toList([[new $cbor.Int(2), new $cbor.Bytes(kid$1)]]);
  } else {
    _block = $List$Empty$const;
  }
  let kid_pair = _block;
  return $result.try$(
    resolve_alg_metadata(k),
    (alg_pair) => {
      let _block$1;
      let $1 = $gose.key_ops(k);
      if ($1 instanceof Ok) {
        let ops = $1[0];
        _block$1 = toList([
          [
            new $cbor.Int(4),
            new $cbor.Array(
              $list.map(
                ops,
                (op) => { return new $cbor.Int(key_op_to_cose(op)); },
              ),
            ),
          ],
        ]);
      } else {
        _block$1 = $List$Empty$const;
      }
      let ops_pair = _block$1;
      return new Ok($list.flatten(toList([kid_pair, alg_pair, ops_pair])));
    },
  );
}

function encode_symmetric(secret) {
  return toList([
    [new $cbor.Int(1), new $cbor.Int(4)],
    [new $cbor.Int(-1), new $cbor.Bytes(secret)],
  ]);
}

function encode_rsa(mat) {
  if (mat instanceof $gose.RsaPrivate) {
    let priv = mat.key;
    let public_key = mat.public;
    let n = $utils.strip_leading_zeros($rsa.public_key_modulus(public_key));
    let e = $utils.strip_leading_zeros(
      $rsa.public_key_exponent_bytes(public_key),
    );
    return toList([
      [new $cbor.Int(1), new $cbor.Int(3)],
      [new $cbor.Int(-1), new $cbor.Bytes(n)],
      [new $cbor.Int(-2), new $cbor.Bytes(e)],
      [new $cbor.Int(-3), new $cbor.Bytes($rsa.private_exponent_bytes(priv))],
      [new $cbor.Int(-4), new $cbor.Bytes($rsa.prime1(priv))],
      [new $cbor.Int(-5), new $cbor.Bytes($rsa.prime2(priv))],
      [new $cbor.Int(-6), new $cbor.Bytes($rsa.exponent1(priv))],
      [new $cbor.Int(-7), new $cbor.Bytes($rsa.exponent2(priv))],
      [new $cbor.Int(-8), new $cbor.Bytes($rsa.coefficient(priv))],
    ]);
  } else {
    let public_key = mat.key;
    let n = $utils.strip_leading_zeros($rsa.public_key_modulus(public_key));
    let e = $utils.strip_leading_zeros(
      $rsa.public_key_exponent_bytes(public_key),
    );
    return toList([
      [new $cbor.Int(1), new $cbor.Int(3)],
      [new $cbor.Int(-1), new $cbor.Bytes(n)],
      [new $cbor.Int(-2), new $cbor.Bytes(e)],
    ]);
  }
}

export function xdh_curve_to_cose(curve) {
  if (curve instanceof $xdh.X25519) {
    return 4;
  } else {
    return 5;
  }
}

function encode_xdh(mat) {
  let _block;
  if (mat instanceof $gose.XdhPrivate) {
    let priv = mat.key;
    let public_key = mat.public;
    let c = mat.curve;
    _block = [
      c,
      $xdh.public_key_to_bytes(public_key),
      new $option.Some($xdh.to_bytes(priv)),
    ];
  } else {
    let public_key = mat.key;
    let c = mat.curve;
    _block = [
      c,
      $xdh.public_key_to_bytes(public_key),
      $option.Option$None$const,
    ];
  }
  let $ = _block;
  let curve = $[0];
  let public_bytes = $[1];
  let private_d = $[2];
  let crv_id = xdh_curve_to_cose(curve);
  let pairs = toList([
    [new $cbor.Int(1), new $cbor.Int(1)],
    [new $cbor.Int(-1), new $cbor.Int(crv_id)],
    [new $cbor.Int(-2), new $cbor.Bytes(public_bytes)],
  ]);
  if (private_d instanceof $option.Some) {
    let d = private_d[0];
    return listPrepend([new $cbor.Int(-4), new $cbor.Bytes(d)], pairs);
  } else {
    return pairs;
  }
}

function eddsa_curve_to_cose(curve) {
  if (curve instanceof $eddsa.Ed25519) {
    return 6;
  } else {
    return 7;
  }
}

function encode_eddsa(mat) {
  let _block;
  if (mat instanceof $gose.EddsaPrivate) {
    let priv = mat.key;
    let public_key = mat.public;
    let c = mat.curve;
    _block = [
      c,
      $eddsa.public_key_to_bytes(public_key),
      new $option.Some($eddsa.to_bytes(priv)),
    ];
  } else {
    let public_key = mat.key;
    let c = mat.curve;
    _block = [
      c,
      $eddsa.public_key_to_bytes(public_key),
      $option.Option$None$const,
    ];
  }
  let $ = _block;
  let curve = $[0];
  let public_bytes = $[1];
  let private_d = $[2];
  let crv_id = eddsa_curve_to_cose(curve);
  let pairs = toList([
    [new $cbor.Int(1), new $cbor.Int(1)],
    [new $cbor.Int(-1), new $cbor.Int(crv_id)],
    [new $cbor.Int(-2), new $cbor.Bytes(public_bytes)],
  ]);
  if (private_d instanceof $option.Some) {
    let d = private_d[0];
    return listPrepend([new $cbor.Int(-4), new $cbor.Bytes(d)], pairs);
  } else {
    return pairs;
  }
}

export function ec_curve_to_cose(curve) {
  if (curve instanceof $ec.P256) {
    return 1;
  } else if (curve instanceof $ec.P384) {
    return 2;
  } else if (curve instanceof $ec.P521) {
    return 3;
  } else {
    return 8;
  }
}

function encode_ec(mat) {
  let _block;
  if (mat instanceof $gose.EcPrivate) {
    let priv = mat.key;
    let public_key = mat.public;
    let c = mat.curve;
    _block = [c, public_key, new $option.Some(priv)];
  } else {
    let public_key = mat.key;
    let c = mat.curve;
    _block = [c, public_key, $option.Option$None$const];
  }
  let $ = _block;
  let curve = $[0];
  let public$ = $[1];
  let private_d = $[2];
  let crv_id = ec_curve_to_cose(curve);
  let raw_point = $ec.public_key_to_raw_point(public$);
  let coord_size = $ec.coordinate_size(curve);
  let $1 = $bit_array.slice(raw_point, 1, coord_size);
  let x;
  if ($1 instanceof Ok) {
    x = $1[0];
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose",
      371,
      "encode_ec",
      "Pattern match failed, no pattern matched the value.",
      {
        value: $1,
        start: 10147,
        end: 10207,
        pattern_start: 10158,
        pattern_end: 10163
      }
    )
  }
  let $2 = $bit_array.slice(raw_point, 1 + coord_size, coord_size);
  let y;
  if ($2 instanceof Ok) {
    y = $2[0];
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose",
      372,
      "encode_ec",
      "Pattern match failed, no pattern matched the value.",
      {
        value: $2,
        start: 10210,
        end: 10283,
        pattern_start: 10221,
        pattern_end: 10226
      }
    )
  }
  let pairs = toList([
    [new $cbor.Int(1), new $cbor.Int(2)],
    [new $cbor.Int(-1), new $cbor.Int(crv_id)],
    [new $cbor.Int(-2), new $cbor.Bytes(x)],
    [new $cbor.Int(-3), new $cbor.Bytes(y)],
  ]);
  if (private_d instanceof $option.Some) {
    let priv = private_d[0];
    return listPrepend(
      [new $cbor.Int(-4), new $cbor.Bytes($ec.to_bytes(priv))],
      pairs,
    );
  } else {
    return pairs;
  }
}

function encode_key_material(mat) {
  if (mat instanceof $gose.OctetKey) {
    let secret = mat.secret;
    return new Ok(encode_symmetric(secret));
  } else if (mat instanceof $gose.Rsa) {
    let rsa_mat = mat[0];
    return new Ok(encode_rsa(rsa_mat));
  } else if (mat instanceof $gose.Elliptic) {
    let ec_mat = mat[0];
    return new Ok(encode_ec(ec_mat));
  } else if (mat instanceof $gose.Edwards) {
    let eddsa_mat = mat[0];
    return new Ok(encode_eddsa(eddsa_mat));
  } else {
    let xdh_mat = mat[0];
    return new Ok(encode_xdh(xdh_mat));
  }
}

/**
 * Encode a `Key` to its CBOR map entries, for embedding in larger
 * CBOR structures.
 */
export function key_to_cbor_map(k) {
  let mat = $gose.material(k);
  return $result.try$(
    encode_key_material(mat),
    (key_pairs) => {
      return $result.try$(
        encode_metadata(k),
        (metadata_pairs) => {
          return new Ok($list.append(key_pairs, metadata_pairs));
        },
      );
    },
  );
}

/**
 * Encode a `Key` to COSE_Key CBOR bytes ([RFC 9052](https://www.rfc-editor.org/rfc/rfc9052.html)).
 */
export function key_to_cbor(k) {
  return $result.try$(
    key_to_cbor_map(k),
    (pairs) => { return new Ok($cbor.encode(new $cbor.Map(pairs))); },
  );
}

function key_op_from_cose(id) {
  if (id === 1) {
    return new Ok($gose.KeyOp$Sign$const);
  } else if (id === 2) {
    return new Ok($gose.KeyOp$Verify$const);
  } else if (id === 3) {
    return new Ok($gose.KeyOp$Encrypt$const);
  } else if (id === 4) {
    return new Ok($gose.KeyOp$Decrypt$const);
  } else if (id === 5) {
    return new Ok($gose.KeyOp$WrapKey$const);
  } else if (id === 6) {
    return new Ok($gose.KeyOp$UnwrapKey$const);
  } else if (id === 7) {
    return new Ok($gose.KeyOp$DeriveKey$const);
  } else if (id === 8) {
    return new Ok($gose.KeyOp$DeriveBits$const);
  } else {
    return new Error(
      new $gose.ParseError("unknown COSE key_op: " + $int.to_string(id)),
    );
  }
}

function decode_key_ops(ops) {
  return $list.try_map(
    ops,
    (v) => {
      if (v instanceof $cbor.Int) {
        let id = v[0];
        return key_op_from_cose(id);
      } else {
        return new Error(new $gose.ParseError("key_ops must contain integers"));
      }
    },
  );
}

function lookup_array_optional(map, label) {
  let $ = $list.key_find(map, new $cbor.Int(label));
  if ($ instanceof Ok) {
    let $1 = $[0];
    if ($1 instanceof $cbor.Array) {
      let items = $1[0];
      return new Ok(new $option.Some(items));
    } else {
      return new Error(
        new $gose.ParseError(
          ("key parameter " + $int.to_string(label)) + " has wrong type",
        ),
      );
    }
  } else {
    return new Ok($option.Option$None$const);
  }
}

function apply_key_ops(k, map) {
  return $result.try$(
    lookup_array_optional(map, 4),
    (opt_ops) => {
      if (opt_ops instanceof $option.Some) {
        let ops_cbor = opt_ops[0];
        return $result.try$(
          decode_key_ops(ops_cbor),
          (ops) => { return $gose.with_key_ops(k, ops); },
        );
      } else {
        return new Ok(k);
      }
    },
  );
}

/**
 * Parse a content encryption algorithm from its COSE integer identifier.
 */
export function content_alg_from_int(id) {
  if (id === 1) {
    return new Ok(new $gose.AesGcm($gose.AesKeySize$Aes128$const));
  } else if (id === 2) {
    return new Ok(new $gose.AesGcm($gose.AesKeySize$Aes192$const));
  } else if (id === 3) {
    return new Ok(new $gose.AesGcm($gose.AesKeySize$Aes256$const));
  } else if (id === 24) {
    return new Ok($gose.ContentAlg$ChaCha20Poly1305$const);
  } else {
    return new Error(
      new $gose.ParseError(
        "unknown COSE content encryption algorithm: " + $int.to_string(id),
      ),
    );
  }
}

/**
 * Parse a key encryption algorithm from its COSE integer identifier.
 *
 * Both ECDH-ES+HKDF-256 (-25) and ECDH-ES+HKDF-512 (-26) map to
 * `EcdhEs(EcdhEsDirect)` because the shared algorithm type does not
 * distinguish the HKDF variant. The HKDF variant is preserved at the
 * `cose/encrypt` layer via `EcdhEsDirectVariant`. Use
 * `new_ecdh_es_direct_recipient` and `ecdh_es_direct_decryptor` for
 * HKDF-512 support.
 */
export function key_encryption_alg_from_int(id) {
  if (id === -25) {
    return new Ok(new $gose.EcdhEs($gose.EcdhEsAlg$EcdhEsDirect$const));
  } else if (id === -26) {
    return new Ok(new $gose.EcdhEs($gose.EcdhEsAlg$EcdhEsDirect$const));
  } else if (id === -29) {
    return new Ok(
      new $gose.EcdhEs(new $gose.EcdhEsAesKw($gose.AesKeySize$Aes128$const)),
    );
  } else if (id === -3) {
    return new Ok(
      new $gose.AesKeyWrap(
        $gose.AesKwMode$AesKw$const,
        $gose.AesKeySize$Aes128$const,
      ),
    );
  } else if (id === -30) {
    return new Ok(
      new $gose.EcdhEs(new $gose.EcdhEsAesKw($gose.AesKeySize$Aes192$const)),
    );
  } else if (id === -31) {
    return new Ok(
      new $gose.EcdhEs(new $gose.EcdhEsAesKw($gose.AesKeySize$Aes256$const)),
    );
  } else if (id === -4) {
    return new Ok(
      new $gose.AesKeyWrap(
        $gose.AesKwMode$AesKw$const,
        $gose.AesKeySize$Aes192$const,
      ),
    );
  } else if (id === -5) {
    return new Ok(
      new $gose.AesKeyWrap(
        $gose.AesKwMode$AesKw$const,
        $gose.AesKeySize$Aes256$const,
      ),
    );
  } else if (id === -6) {
    return new Ok($gose.KeyEncryptionAlg$Direct$const);
  } else if (id === -40) {
    return new Ok(
      new $gose.RsaEncryption($gose.RsaEncryptionAlg$RsaOaepSha1$const),
    );
  } else if (id === -41) {
    return new Ok(
      new $gose.RsaEncryption($gose.RsaEncryptionAlg$RsaOaepSha256$const),
    );
  } else {
    return new Error(
      new $gose.ParseError(
        "unknown COSE key encryption algorithm: " + $int.to_string(id),
      ),
    );
  }
}

/**
 * Parse a MAC algorithm from its COSE integer identifier.
 */
export function mac_alg_from_int(id) {
  if (id === 5) {
    return new Ok(new $gose.Hmac($gose.HmacAlg$HmacSha256$const));
  } else if (id === 6) {
    return new Ok(new $gose.Hmac($gose.HmacAlg$HmacSha384$const));
  } else if (id === 7) {
    return new Ok(new $gose.Hmac($gose.HmacAlg$HmacSha512$const));
  } else {
    return new Error(
      new $gose.ParseError("unknown COSE MAC algorithm: " + $int.to_string(id)),
    );
  }
}

/**
 * Parse a signature algorithm from its COSE integer identifier.
 */
export function signature_alg_from_int(id) {
  if (id === -257) {
    return new Ok(new $gose.RsaPkcs1($gose.RsaPkcs1Alg$RsaPkcs1Sha256$const));
  } else if (id === -258) {
    return new Ok(new $gose.RsaPkcs1($gose.RsaPkcs1Alg$RsaPkcs1Sha384$const));
  } else if (id === -259) {
    return new Ok(new $gose.RsaPkcs1($gose.RsaPkcs1Alg$RsaPkcs1Sha512$const));
  } else if (id === -35) {
    return new Ok(new $gose.Ecdsa($gose.EcdsaAlg$EcdsaP384$const));
  } else if (id === -36) {
    return new Ok(new $gose.Ecdsa($gose.EcdsaAlg$EcdsaP521$const));
  } else if (id === -37) {
    return new Ok(new $gose.RsaPss($gose.RsaPssAlg$RsaPssSha256$const));
  } else if (id === -38) {
    return new Ok(new $gose.RsaPss($gose.RsaPssAlg$RsaPssSha384$const));
  } else if (id === -39) {
    return new Ok(new $gose.RsaPss($gose.RsaPssAlg$RsaPssSha512$const));
  } else if (id === -47) {
    return new Ok(new $gose.Ecdsa($gose.EcdsaAlg$EcdsaSecp256k1$const));
  } else if (id === -7) {
    return new Ok(new $gose.Ecdsa($gose.EcdsaAlg$EcdsaP256$const));
  } else if (id === -8) {
    return new Ok($gose.DigitalSignatureAlg$Eddsa$const);
  } else {
    return new Error(
      new $gose.ParseError(
        "unknown COSE signature algorithm: " + $int.to_string(id),
      ),
    );
  }
}

/**
 * Parse a signing algorithm from its COSE integer identifier.
 */
export function signing_alg_from_int(id) {
  let $ = signature_alg_from_int(id);
  if ($ instanceof Ok) {
    let alg = $[0];
    return new Ok(new $gose.DigitalSignature(alg));
  } else {
    let $1 = mac_alg_from_int(id);
    if ($1 instanceof Ok) {
      let alg = $1[0];
      return new Ok(new $gose.Mac(alg));
    } else {
      return new Error(
        new $gose.ParseError(
          "unknown COSE signing algorithm: " + $int.to_string(id),
        ),
      );
    }
  }
}

function decode_alg(id) {
  let $ = signing_alg_from_int(id);
  if ($ instanceof Ok) {
    let alg = $[0];
    return new Ok(new $gose.SigningAlg(alg));
  } else {
    let $1 = key_encryption_alg_from_int(id);
    if ($1 instanceof Ok) {
      let alg = $1[0];
      return new Ok(new $gose.KeyEncryptionAlg(alg));
    } else {
      let _pipe = content_alg_from_int(id);
      let _pipe$1 = $result.map(
        _pipe,
        (var0) => { return new $gose.ContentAlg(var0); },
      );
      return $result.replace_error(
        _pipe$1,
        new $gose.ParseError("unknown COSE algorithm: " + $int.to_string(id)),
      );
    }
  }
}

function lookup_int_optional(map, label) {
  let $ = $list.key_find(map, new $cbor.Int(label));
  if ($ instanceof Ok) {
    let $1 = $[0];
    if ($1 instanceof $cbor.Int) {
      let value = $1[0];
      return new Ok(new $option.Some(value));
    } else {
      return new Error(
        new $gose.ParseError(
          ("key parameter " + $int.to_string(label)) + " has wrong type",
        ),
      );
    }
  } else {
    return new Ok($option.Option$None$const);
  }
}

function apply_alg(k, map) {
  return $result.try$(
    lookup_int_optional(map, 3),
    (opt_alg_id) => {
      if (opt_alg_id instanceof $option.Some) {
        let alg_id = opt_alg_id[0];
        return $result.map(
          decode_alg(alg_id),
          (alg) => { return $gose.with_alg(k, alg); },
        );
      } else {
        return new Ok(k);
      }
    },
  );
}

function lookup_bytes_optional(map, label) {
  let $ = $list.key_find(map, new $cbor.Int(label));
  if ($ instanceof Ok) {
    let $1 = $[0];
    if ($1 instanceof $cbor.Bytes) {
      let value = $1[0];
      return new Ok(new $option.Some(value));
    } else {
      return new Error(
        new $gose.ParseError(
          ("key parameter " + $int.to_string(label)) + " has wrong type",
        ),
      );
    }
  } else {
    return new Ok($option.Option$None$const);
  }
}

function apply_kid(k, map) {
  return $result.try$(
    lookup_bytes_optional(map, 2),
    (opt_kid) => {
      if (opt_kid instanceof $option.Some) {
        let kid_bytes = opt_kid[0];
        return new Ok($gose.with_kid_bits(k, kid_bytes));
      } else {
        return new Ok(k);
      }
    },
  );
}

function apply_metadata(k, map) {
  return $result.try$(
    apply_kid(k, map),
    (k) => {
      return $result.try$(
        apply_alg(k, map),
        (k) => { return apply_key_ops(k, map); },
      );
    },
  );
}

function lookup_bytes(map, label, error_msg) {
  let $ = $list.key_find(map, new $cbor.Int(label));
  if ($ instanceof Ok) {
    let $1 = $[0];
    if ($1 instanceof $cbor.Bytes) {
      let value = $1[0];
      return new Ok(value);
    } else {
      return new Error(new $gose.ParseError(error_msg + " (wrong type)"));
    }
  } else {
    return new Error(new $gose.ParseError(error_msg));
  }
}

function decode_symmetric(map) {
  return $result.try$(
    lookup_bytes(map, -1, "missing symmetric key (label -1)"),
    (k) => { return $gose.from_octet_bits(k); },
  );
}

function has_label(map, label) {
  let _pipe = $list.key_find(map, new $cbor.Int(label));
  return $result.is_ok(_pipe);
}

function decode_rsa_private(map, n, e) {
  return $result.try$(
    lookup_bytes(map, -3, "missing RSA d (label -3)"),
    (d) => {
      let $ = has_label(map, -4);
      if ($) {
        return $result.try$(
          lookup_bytes(map, -4, "missing RSA p (label -4)"),
          (p) => {
            return $result.try$(
              lookup_bytes(map, -5, "missing RSA q (label -5)"),
              (q) => {
                return $result.try$(
                  lookup_bytes(map, -6, "missing RSA dp (label -6)"),
                  (dp) => {
                    return $result.try$(
                      lookup_bytes(map, -7, "missing RSA dq (label -7)"),
                      (dq) => {
                        return $result.try$(
                          lookup_bytes(map, -8, "missing RSA qi (label -8)"),
                          (qi) => {
                            let _pipe = $rsa.from_full_components(
                              n,
                              e,
                              d,
                              p,
                              q,
                              dp,
                              dq,
                              qi,
                            );
                            let _pipe$1 = $result.replace_error(
                              _pipe,
                              new $gose.ParseError(
                                "invalid RSA private key components",
                              ),
                            );
                            return $result.map(
                              _pipe$1,
                              (pair) => {
                                let private$ = pair[0];
                                let public$ = pair[1];
                                return $gose.new_key(
                                  new $gose.Rsa(
                                    new $gose.RsaPrivate(private$, public$),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      } else {
        let _pipe = $rsa.from_components(n, e, d);
        let _pipe$1 = $result.replace_error(
          _pipe,
          new $gose.ParseError("invalid RSA private key components"),
        );
        return $result.map(
          _pipe$1,
          (pair) => {
            let private$ = pair[0];
            let public$ = pair[1];
            return $gose.new_key(
              new $gose.Rsa(new $gose.RsaPrivate(private$, public$)),
            );
          },
        );
      }
    },
  );
}

function decode_rsa(map) {
  return $result.try$(
    lookup_bytes(map, -1, "missing RSA n (label -1)"),
    (n) => {
      return $result.try$(
        lookup_bytes(map, -2, "missing RSA e (label -2)"),
        (e) => {
          let $ = has_label(map, -3);
          if ($) {
            return decode_rsa_private(map, n, e);
          } else {
            let _pipe = $rsa.public_key_from_components(n, e);
            let _pipe$1 = $result.replace_error(
              _pipe,
              new $gose.ParseError("invalid RSA public key components"),
            );
            return $result.map(
              _pipe$1,
              (public_key) => {
                return $gose.new_key(
                  new $gose.Rsa(new $gose.RsaPublic(public_key)),
                );
              },
            );
          }
        },
      );
    },
  );
}

export function ec_curve_from_cose(id) {
  if (id === 1) {
    return new Ok($ec.Curve$P256$const);
  } else if (id === 2) {
    return new Ok($ec.Curve$P384$const);
  } else if (id === 3) {
    return new Ok($ec.Curve$P521$const);
  } else if (id === 8) {
    return new Ok($ec.Curve$Secp256k1$const);
  } else {
    return new Error(
      new $gose.ParseError("unsupported COSE EC curve: " + $int.to_string(id)),
    );
  }
}

function lookup_int(map, label, error_msg) {
  let $ = $list.key_find(map, new $cbor.Int(label));
  if ($ instanceof Ok) {
    let $1 = $[0];
    if ($1 instanceof $cbor.Int) {
      let value = $1[0];
      return new Ok(value);
    } else {
      return new Error(new $gose.ParseError(error_msg + " (wrong type)"));
    }
  } else {
    return new Error(new $gose.ParseError(error_msg));
  }
}

function decode_ec2(map) {
  return $result.try$(
    lookup_int(map, -1, "missing EC curve (label -1)"),
    (crv_id) => {
      return $result.try$(
        ec_curve_from_cose(crv_id),
        (curve) => {
          return $result.try$(
            lookup_bytes(map, -2, "missing EC x (label -2)"),
            (x) => {
              return $result.try$(
                lookup_bytes(map, -3, "missing EC y (label -3)"),
                (y) => {
                  let $ = has_label(map, -4);
                  if ($) {
                    return $result.try$(
                      lookup_bytes(map, -4, "missing EC d (label -4)"),
                      (d) => {
                        return $result.try$(
                          (() => {
                            let _pipe = $ec.from_bytes(curve, d);
                            return $result.replace_error(
                              _pipe,
                              new $gose.ParseError("invalid EC private key"),
                            );
                          })(),
                          (_use0) => {
                            let private$ = _use0[0];
                            let public$ = _use0[1];
                            let computed_point = $ec.public_key_to_raw_point(
                              public$,
                            );
                            let raw_point = $bit_array.concat(
                              toList([toBitArray([4]), x, y]),
                            );
                            return $bool.guard(
                              !$crypto.constant_time_equal(
                                computed_point,
                                raw_point,
                              ),
                              new Error(
                                new $gose.ParseError(
                                  "x/y do not match computed public key",
                                ),
                              ),
                              () => {
                                return new Ok(
                                  $gose.new_key(
                                    new $gose.Elliptic(
                                      new $gose.EcPrivate(
                                        private$,
                                        public$,
                                        curve,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  } else {
                    return $gose.ec_public_key_from_coordinates(curve, x, y);
                  }
                },
              );
            },
          );
        },
      );
    },
  );
}

function decode_xdh_key(curve, map) {
  let $ = has_label(map, -4);
  if ($) {
    return $result.try$(
      lookup_bytes(map, -2, "missing XDH x (label -2)"),
      (x) => {
        return $result.try$(
          lookup_bytes(map, -4, "missing XDH d (label -4)"),
          (d) => {
            return $result.try$(
              (() => {
                let _pipe = $xdh.from_bytes(curve, d);
                return $result.replace_error(
                  _pipe,
                  new $gose.ParseError("invalid XDH private key"),
                );
              })(),
              (_use0) => {
                let private$ = _use0[0];
                let public$ = _use0[1];
                let computed_x = $xdh.public_key_to_bytes(public$);
                return $bool.guard(
                  !$crypto.constant_time_equal(computed_x, x),
                  new Error(
                    new $gose.ParseError("x does not match computed public key"),
                  ),
                  () => {
                    return new Ok(
                      $gose.new_key(
                        new $gose.Xdh(
                          new $gose.XdhPrivate(private$, public$, curve),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  } else {
    return $result.try$(
      lookup_bytes(map, -2, "missing XDH x (label -2)"),
      (x) => { return $gose.from_xdh_public_bits(curve, x); },
    );
  }
}

function decode_eddsa_key(curve, map) {
  let $ = has_label(map, -4);
  if ($) {
    return $result.try$(
      lookup_bytes(map, -2, "missing EdDSA x (label -2)"),
      (x) => {
        return $result.try$(
          lookup_bytes(map, -4, "missing EdDSA d (label -4)"),
          (d) => {
            return $result.try$(
              (() => {
                let _pipe = $eddsa.from_bytes(curve, d);
                return $result.replace_error(
                  _pipe,
                  new $gose.ParseError("invalid EdDSA private key"),
                );
              })(),
              (_use0) => {
                let private$ = _use0[0];
                let public$ = _use0[1];
                let computed_x = $eddsa.public_key_to_bytes(public$);
                return $bool.guard(
                  !$crypto.constant_time_equal(computed_x, x),
                  new Error(
                    new $gose.ParseError("x does not match computed public key"),
                  ),
                  () => {
                    return new Ok(
                      $gose.new_key(
                        new $gose.Edwards(
                          new $gose.EddsaPrivate(private$, public$, curve),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  } else {
    return $result.try$(
      lookup_bytes(map, -2, "missing EdDSA x (label -2)"),
      (x) => { return $gose.from_eddsa_public_bits(curve, x); },
    );
  }
}

function decode_okp(map) {
  return $result.try$(
    lookup_int(map, -1, "missing OKP curve (label -1)"),
    (crv_id) => {
      if (crv_id === 6) {
        return decode_eddsa_key($eddsa.Curve$Ed25519$const, map);
      } else if (crv_id === 7) {
        return decode_eddsa_key($eddsa.Curve$Ed448$const, map);
      } else if (crv_id === 4) {
        return decode_xdh_key($xdh.Curve$X25519$const, map);
      } else if (crv_id === 5) {
        return decode_xdh_key($xdh.Curve$X448$const, map);
      } else {
        return new Error(
          new $gose.ParseError(
            "unsupported OKP curve: " + $int.to_string(crv_id),
          ),
        );
      }
    },
  );
}

function decode_key_by_type(kty, map) {
  if (kty === 1) {
    return decode_okp(map);
  } else if (kty === 2) {
    return decode_ec2(map);
  } else if (kty === 3) {
    return decode_rsa(map);
  } else if (kty === 4) {
    return decode_symmetric(map);
  } else {
    return new Error(
      new $gose.ParseError("unsupported COSE key type: " + $int.to_string(kty)),
    );
  }
}

/**
 * Decode CBOR map entries to a `Key`.
 */
export function key_from_cbor_map(map) {
  return $result.try$(
    lookup_int(map, 1, "missing kty (label 1)"),
    (kty) => {
      return $result.try$(
        decode_key_by_type(kty, map),
        (base_key) => { return apply_metadata(base_key, map); },
      );
    },
  );
}

/**
 * Decode COSE_Key bytes to a `Key`.
 */
export function key_from_cbor(data) {
  return $result.try$(
    $cbor.decode(data),
    (value) => {
      if (value instanceof $cbor.Map) {
        let pairs = value[0];
        return key_from_cbor_map(pairs);
      } else {
        return new Error(new $gose.ParseError("COSE_Key must be a CBOR map"));
      }
    },
  );
}

export function xdh_curve_from_cose(id) {
  if (id === 4) {
    return new Ok($xdh.Curve$X25519$const);
  } else if (id === 5) {
    return new Ok($xdh.Curve$X448$const);
  } else {
    return new Error(
      new $gose.ParseError("unsupported COSE XDH curve: " + $int.to_string(id)),
    );
  }
}
