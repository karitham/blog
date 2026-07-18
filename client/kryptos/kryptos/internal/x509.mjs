import * as $bit_array from "../../../gleam_stdlib/gleam/bit_array.mjs";
import * as $bool from "../../../gleam_stdlib/gleam/bool.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import * as $string from "../../../gleam_stdlib/gleam/string.mjs";
import * as $string_tree from "../../../gleam_stdlib/gleam/string_tree.mjs";
import {
  Ok,
  Error,
  toList,
  Empty as $Empty,
  prepend as listPrepend,
  CustomType as $CustomType,
  makeError,
  isEqual,
  toBitArray,
  bitArraySlice,
} from "../../gleam.mjs";
import * as $ec from "../../kryptos/ec.mjs";
import * as $ecdsa from "../../kryptos/ecdsa.mjs";
import * as $eddsa from "../../kryptos/eddsa.mjs";
import * as $hash from "../../kryptos/hash.mjs";
import * as $der from "../../kryptos/internal/der.mjs";
import * as $utils from "../../kryptos/internal/utils.mjs";
import * as $rsa from "../../kryptos/rsa.mjs";
import * as $x509 from "../../kryptos/x509.mjs";
import * as $xdh from "../../kryptos/xdh.mjs";

const FILEPATH = "src/kryptos/internal/x509.gleam";

class PemNotFound extends $CustomType {}

class PemMalformed extends $CustomType {}

export class SigAlgInfo extends $CustomType {
  constructor(oid, include_null_params) {
    super();
    this.oid = oid;
    this.include_null_params = include_null_params;
  }
}
export const SigAlgInfo$SigAlgInfo = (oid, include_null_params) =>
  new SigAlgInfo(oid, include_null_params);
export const SigAlgInfo$isSigAlgInfo = (value) => value instanceof SigAlgInfo;
export const SigAlgInfo$SigAlgInfo$oid = (value) => value.oid;
export const SigAlgInfo$SigAlgInfo$0 = (value) => value.oid;
export const SigAlgInfo$SigAlgInfo$include_null_params = (value) =>
  value.include_null_params;
export const SigAlgInfo$SigAlgInfo$1 = (value) => value.include_null_params;

const oid_ecdsa_with_sha512 = /* @__PURE__ */ new $x509.Oid(
  /* @__PURE__ */ toList([1, 2, 840, 10_045, 4, 3, 4]),
);

const oid_ecdsa_with_sha384 = /* @__PURE__ */ new $x509.Oid(
  /* @__PURE__ */ toList([1, 2, 840, 10_045, 4, 3, 3]),
);

const oid_ecdsa_with_sha256 = /* @__PURE__ */ new $x509.Oid(
  /* @__PURE__ */ toList([1, 2, 840, 10_045, 4, 3, 2]),
);

const oid_ecdsa_with_sha1 = /* @__PURE__ */ new $x509.Oid(
  /* @__PURE__ */ toList([1, 2, 840, 10_045, 4, 1]),
);

const oid_rsa_with_sha512 = /* @__PURE__ */ new $x509.Oid(
  /* @__PURE__ */ toList([1, 2, 840, 113_549, 1, 1, 13]),
);

const oid_rsa_with_sha384 = /* @__PURE__ */ new $x509.Oid(
  /* @__PURE__ */ toList([1, 2, 840, 113_549, 1, 1, 12]),
);

const oid_rsa_with_sha256 = /* @__PURE__ */ new $x509.Oid(
  /* @__PURE__ */ toList([1, 2, 840, 113_549, 1, 1, 11]),
);

const oid_rsa_with_sha1 = /* @__PURE__ */ new $x509.Oid(
  /* @__PURE__ */ toList([1, 2, 840, 113_549, 1, 1, 5]),
);

const oid_ed448 = /* @__PURE__ */ new $x509.Oid(
  /* @__PURE__ */ toList([1, 3, 101, 113]),
);

const oid_ed25519 = /* @__PURE__ */ new $x509.Oid(
  /* @__PURE__ */ toList([1, 3, 101, 112]),
);

/**
 * Map a hash algorithm to ECDSA signature algorithm information.
 */
export function ecdsa_sig_alg_info(hash) {
  if (hash instanceof $hash.Sha1) {
    return new Ok(new SigAlgInfo(oid_ecdsa_with_sha1, false));
  } else if (hash instanceof $hash.Sha256) {
    return new Ok(new SigAlgInfo(oid_ecdsa_with_sha256, false));
  } else if (hash instanceof $hash.Sha384) {
    return new Ok(new SigAlgInfo(oid_ecdsa_with_sha384, false));
  } else if (hash instanceof $hash.Sha512) {
    return new Ok(new SigAlgInfo(oid_ecdsa_with_sha512, false));
  } else {
    return new Error(undefined);
  }
}

/**
 * Map a hash algorithm to RSA signature algorithm information.
 */
export function rsa_sig_alg_info(hash) {
  if (hash instanceof $hash.Sha1) {
    return new Ok(new SigAlgInfo(oid_rsa_with_sha1, true));
  } else if (hash instanceof $hash.Sha256) {
    return new Ok(new SigAlgInfo(oid_rsa_with_sha256, true));
  } else if (hash instanceof $hash.Sha384) {
    return new Ok(new SigAlgInfo(oid_rsa_with_sha384, true));
  } else if (hash instanceof $hash.Sha512) {
    return new Ok(new SigAlgInfo(oid_rsa_with_sha512, true));
  } else {
    return new Error(undefined);
  }
}

/**
 * Map an EdDSA curve to signature algorithm information.
 */
export function eddsa_sig_alg_info(curve) {
  if (curve instanceof $eddsa.Ed25519) {
    return new SigAlgInfo(oid_ed25519, false);
  } else {
    return new SigAlgInfo(oid_ed448, false);
  }
}

function sig_alg_to_hash(sig_alg) {
  if (sig_alg instanceof $x509.RsaSha1) {
    return new Ok(new $hash.Sha1());
  } else if (sig_alg instanceof $x509.RsaSha256) {
    return new Ok(new $hash.Sha256());
  } else if (sig_alg instanceof $x509.RsaSha384) {
    return new Ok(new $hash.Sha384());
  } else if (sig_alg instanceof $x509.RsaSha512) {
    return new Ok(new $hash.Sha512());
  } else if (sig_alg instanceof $x509.EcdsaSha1) {
    return new Ok(new $hash.Sha1());
  } else if (sig_alg instanceof $x509.EcdsaSha256) {
    return new Ok(new $hash.Sha256());
  } else if (sig_alg instanceof $x509.EcdsaSha384) {
    return new Ok(new $hash.Sha384());
  } else if (sig_alg instanceof $x509.EcdsaSha512) {
    return new Ok(new $hash.Sha512());
  } else if (sig_alg instanceof $x509.Ed25519) {
    return new Error(undefined);
  } else {
    return new Error(undefined);
  }
}

/**
 * Verify a signature using the appropriate algorithm based on public key and signature algorithm.
 */
export function verify_signature(
  public_key,
  data,
  signature,
  signature_algorithm
) {
  if (public_key instanceof $x509.EcPublicKey) {
    let sig_alg = signature_algorithm;
    let key = public_key[0];
    let $ = sig_alg_to_hash(sig_alg);
    if ($ instanceof Ok) {
      let hash_alg = $[0];
      return $ecdsa.verify(key, data, signature, hash_alg);
    } else {
      return false;
    }
  } else if (public_key instanceof $x509.RsaPublicKey) {
    let sig_alg = signature_algorithm;
    let key = public_key[0];
    let $ = sig_alg_to_hash(sig_alg);
    if ($ instanceof Ok) {
      let hash_alg = $[0];
      return $rsa.verify(key, data, signature, hash_alg, new $rsa.Pkcs1v15());
    } else {
      return false;
    }
  } else if (public_key instanceof $x509.EdPublicKey) {
    if (signature_algorithm instanceof $x509.Ed25519) {
      let key = public_key[0];
      return $eddsa.verify(key, data, signature);
    } else if (signature_algorithm instanceof $x509.Ed448) {
      let key = public_key[0];
      return $eddsa.verify(key, data, signature);
    } else {
      return false;
    }
  } else {
    return false;
  }
}

/**
 * Parse a DER SEQUENCE including its tag and length header.
 *
 * Returns the complete SEQUENCE (tag + length + content) and remaining bytes.
 * Returns Error(Nil) if the input does not start with a SEQUENCE tag.
 */
export function parse_sequence_with_header(bytes) {
  if (bytes.bitSize >= 8 && bytes.byteAt(0) === 48) {
    return $result.try$(
      $der.parse_sequence(bytes),
      (_use0) => {
        let inner = _use0[0];
        let remaining = _use0[1];
        let inner_len = $bit_array.byte_size(inner);
        let header_len = ($bit_array.byte_size(bytes) - $bit_array.byte_size(
          remaining,
        )) - inner_len;
        let total_len = header_len + inner_len;
        let $ = $bit_array.slice(bytes, 0, total_len);
        let full_seq;
        if ($ instanceof Ok) {
          full_seq = $[0];
        } else {
          throw makeError(
            "let_assert",
            FILEPATH,
            "kryptos/internal/x509",
            130,
            "parse_sequence_with_header",
            "Pattern match failed, no pattern matched the value.",
            {
              value: $,
              start: 4174,
              end: 4236,
              pattern_start: 4185,
              pattern_end: 4197
            }
          )
        }
        return new Ok([full_seq, remaining]);
      },
    );
  } else {
    return new Error(undefined);
  }
}

/**
 * Parse an X.509 signature algorithm from DER-encoded AlgorithmIdentifier.
 *
 * Decodes the OID and returns the corresponding SignatureAlgorithm variant.
 * Returns Error with the unknown OID if the algorithm is not recognized.
 */
export function parse_signature_algorithm(bytes) {
  let $ = $der.parse_oid(bytes);
  if ($ instanceof Ok) {
    let oid_components = $[0][0];
    if (oid_components instanceof $Empty) {
      return new Error(new $x509.Oid(oid_components));
    } else {
      let $1 = oid_components.tail;
      if ($1 instanceof $Empty) {
        return new Error(new $x509.Oid(oid_components));
      } else {
        let $2 = $1.tail;
        if ($2 instanceof $Empty) {
          return new Error(new $x509.Oid(oid_components));
        } else {
          let $3 = $2.tail;
          if ($3 instanceof $Empty) {
            return new Error(new $x509.Oid(oid_components));
          } else {
            let $4 = $3.tail;
            if ($4 instanceof $Empty) {
              let $5 = oid_components.head;
              if ($5 === 1) {
                let $6 = $1.head;
                if ($6 === 3) {
                  let $7 = $2.head;
                  if ($7 === 101) {
                    let $8 = $3.head;
                    if ($8 === 112) {
                      return new Ok(new $x509.Ed25519());
                    } else if ($8 === 113) {
                      return new Ok(new $x509.Ed448());
                    } else {
                      return new Error(new $x509.Oid(oid_components));
                    }
                  } else {
                    return new Error(new $x509.Oid(oid_components));
                  }
                } else {
                  return new Error(new $x509.Oid(oid_components));
                }
              } else {
                return new Error(new $x509.Oid(oid_components));
              }
            } else {
              let $5 = $4.tail;
              if ($5 instanceof $Empty) {
                return new Error(new $x509.Oid(oid_components));
              } else {
                let $6 = $5.tail;
                if ($6 instanceof $Empty) {
                  let $7 = oid_components.head;
                  if ($7 === 1) {
                    let $8 = $1.head;
                    if ($8 === 2) {
                      let $9 = $2.head;
                      if ($9 === 840) {
                        let $10 = $3.head;
                        if ($10 === 10045) {
                          let $11 = $4.head;
                          if ($11 === 4) {
                            let $12 = $5.head;
                            if ($12 === 1) {
                              return new Ok(new $x509.EcdsaSha1());
                            } else {
                              return new Error(new $x509.Oid(oid_components));
                            }
                          } else {
                            return new Error(new $x509.Oid(oid_components));
                          }
                        } else {
                          return new Error(new $x509.Oid(oid_components));
                        }
                      } else {
                        return new Error(new $x509.Oid(oid_components));
                      }
                    } else {
                      return new Error(new $x509.Oid(oid_components));
                    }
                  } else {
                    return new Error(new $x509.Oid(oid_components));
                  }
                } else {
                  let $7 = $6.tail;
                  if ($7 instanceof $Empty) {
                    let $8 = oid_components.head;
                    if ($8 === 1) {
                      let $9 = $1.head;
                      if ($9 === 2) {
                        let $10 = $2.head;
                        if ($10 === 840) {
                          let $11 = $3.head;
                          if ($11 === 113549) {
                            let $12 = $4.head;
                            if ($12 === 1) {
                              let $13 = $5.head;
                              if ($13 === 1) {
                                let $14 = $6.head;
                                if ($14 === 5) {
                                  return new Ok(new $x509.RsaSha1());
                                } else if ($14 === 11) {
                                  return new Ok(new $x509.RsaSha256());
                                } else if ($14 === 12) {
                                  return new Ok(new $x509.RsaSha384());
                                } else if ($14 === 13) {
                                  return new Ok(new $x509.RsaSha512());
                                } else {
                                  return new Error(
                                    new $x509.Oid(oid_components),
                                  );
                                }
                              } else {
                                return new Error(new $x509.Oid(oid_components));
                              }
                            } else {
                              return new Error(new $x509.Oid(oid_components));
                            }
                          } else if ($11 === 10045) {
                            let $12 = $4.head;
                            if ($12 === 4) {
                              let $13 = $5.head;
                              if ($13 === 3) {
                                let $14 = $6.head;
                                if ($14 === 2) {
                                  return new Ok(new $x509.EcdsaSha256());
                                } else if ($14 === 3) {
                                  return new Ok(new $x509.EcdsaSha384());
                                } else if ($14 === 4) {
                                  return new Ok(new $x509.EcdsaSha512());
                                } else {
                                  return new Error(
                                    new $x509.Oid(oid_components),
                                  );
                                }
                              } else {
                                return new Error(new $x509.Oid(oid_components));
                              }
                            } else {
                              return new Error(new $x509.Oid(oid_components));
                            }
                          } else {
                            return new Error(new $x509.Oid(oid_components));
                          }
                        } else {
                          return new Error(new $x509.Oid(oid_components));
                        }
                      } else {
                        return new Error(new $x509.Oid(oid_components));
                      }
                    } else {
                      return new Error(new $x509.Oid(oid_components));
                    }
                  } else {
                    return new Error(new $x509.Oid(oid_components));
                  }
                }
              }
            }
          }
        }
      }
    }
  } else {
    return new Error(new $x509.Oid(toList([])));
  }
}

function parse_attribute_value(bytes) {
  if (bytes.bitSize >= 8) {
    if (bytes.byteAt(0) === 12) {
      return $result.try$(
        $der.parse_utf8_string(bytes),
        (_use0) => {
          let s = _use0[0];
          let rest = _use0[1];
          return new Ok([$x509.utf8_string(s), rest]);
        },
      );
    } else if (bytes.byteAt(0) === 19) {
      return $result.try$(
        $der.parse_printable_string(bytes),
        (_use0) => {
          let s = _use0[0];
          let rest = _use0[1];
          return new Ok([$x509.printable_string(s), rest]);
        },
      );
    } else if (bytes.byteAt(0) === 20) {
      return $result.try$(
        $der.parse_teletex_string(bytes),
        (_use0) => {
          let s = _use0[0];
          let rest = _use0[1];
          return new Ok([$x509.utf8_string(s), rest]);
        },
      );
    } else if (bytes.byteAt(0) === 22) {
      return $result.try$(
        $der.parse_ia5_string(bytes),
        (_use0) => {
          let s = _use0[0];
          let rest = _use0[1];
          return new Ok([$x509.ia5_string(s), rest]);
        },
      );
    } else if (bytes.byteAt(0) === 28) {
      return $result.try$(
        $der.parse_universal_string(bytes),
        (_use0) => {
          let s = _use0[0];
          let rest = _use0[1];
          return new Ok([$x509.utf8_string(s), rest]);
        },
      );
    } else if (bytes.byteAt(0) === 30) {
      return $result.try$(
        $der.parse_bmp_string(bytes),
        (_use0) => {
          let s = _use0[0];
          let rest = _use0[1];
          return new Ok([$x509.utf8_string(s), rest]);
        },
      );
    } else {
      return new Error(undefined);
    }
  } else {
    return new Error(undefined);
  }
}

function parse_rdn_attributes(bytes, acc) {
  if (bytes.bitSize === 0) {
    return new Ok($list.reverse(acc));
  } else {
    return $result.try$(
      $der.parse_sequence(bytes),
      (_use0) => {
        let attr_bytes = _use0[0];
        let rest = _use0[1];
        return $result.try$(
          $der.parse_oid(attr_bytes),
          (_use0) => {
            let oid_components = _use0[0];
            let after_oid = _use0[1];
            return $result.try$(
              parse_attribute_value(after_oid),
              (_use0) => {
                let value = _use0[0];
                let remaining = _use0[1];
                return $bool.guard(
                  !isEqual(remaining, toBitArray([])),
                  new Error(undefined),
                  () => {
                    return parse_rdn_attributes(
                      rest,
                      listPrepend([new $x509.Oid(oid_components), value], acc),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

function parse_rdns(bytes, acc) {
  if (bytes.bitSize === 0) {
    return new Ok($list.reverse(acc));
  } else {
    return $result.try$(
      $der.parse_set(bytes),
      (_use0) => {
        let rdn_bytes = _use0[0];
        let rest = _use0[1];
        let _pipe = parse_rdn_attributes(rdn_bytes, toList([]));
        return $result.try$(
          _pipe,
          (attributes) => {
            return parse_rdns(rest, listPrepend(new $x509.Rdn(attributes), acc));
          },
        );
      },
    );
  }
}

/**
 * Parse an X.509 distinguished name (DN) from DER encoding.
 *
 * Decodes a Name structure containing RDNs (relative distinguished names).
 * Returns Error(Nil) if the encoding is invalid.
 */
export function parse_name(bytes) {
  let _pipe = parse_rdns(bytes, toList([]));
  return $result.map(_pipe, (var0) => { return new $x509.Name(var0); });
}

function encode_attribute_type_and_value(attr) {
  let oid_components;
  let value;
  value = attr[1];
  oid_components = attr[0].components;
  return $result.try$(
    $x509.encode_attribute_value(value),
    (encoded_value) => {
      return $result.try$(
        $der.encode_oid(oid_components),
        (oid_encoded) => {
          return $der.encode_sequence(
            $bit_array.concat(toList([oid_encoded, encoded_value])),
          );
        },
      );
    },
  );
}

function encode_rdn(rdn) {
  let attributes = rdn.attributes;
  return $result.try$(
    $list.try_map(attributes, encode_attribute_type_and_value),
    (encoded_attrs) => {
      let sorted_attrs = $list.sort(encoded_attrs, $bit_array.compare);
      return $der.encode_set($bit_array.concat(sorted_attrs));
    },
  );
}

/**
 * Encode an X.509 distinguished name to DER format.
 *
 * Produces a DER-encoded Name structure with RDN attributes sorted per RFC 5280.
 * Returns Error(Nil) if encoding fails.
 */
export function encode_name(name) {
  let rdns = name.rdns;
  let _pipe = $list.try_map(rdns, encode_rdn);
  return $result.try$(
    _pipe,
    (encoded_rdns) => {
      return $der.encode_sequence($bit_array.concat(encoded_rdns));
    },
  );
}

function dispatch_public_key_parse(alg_oid, spki_bytes) {
  if (alg_oid instanceof $Empty) {
    return new Error(new $x509.Oid(alg_oid));
  } else {
    let $ = alg_oid.tail;
    if ($ instanceof $Empty) {
      return new Error(new $x509.Oid(alg_oid));
    } else {
      let $1 = $.tail;
      if ($1 instanceof $Empty) {
        return new Error(new $x509.Oid(alg_oid));
      } else {
        let $2 = $1.tail;
        if ($2 instanceof $Empty) {
          return new Error(new $x509.Oid(alg_oid));
        } else {
          let $3 = $2.tail;
          if ($3 instanceof $Empty) {
            let $4 = alg_oid.head;
            if ($4 === 1) {
              let $5 = $.head;
              if ($5 === 3) {
                let $6 = $1.head;
                if ($6 === 101) {
                  let $7 = $2.head;
                  if ($7 === 110) {
                    let _pipe = $xdh.public_key_from_der(spki_bytes);
                    let _pipe$1 = $result.map(
                      _pipe,
                      (var0) => { return new $x509.XdhPublicKey(var0); },
                    );
                    return $result.replace_error(
                      _pipe$1,
                      new $x509.Oid(alg_oid),
                    );
                  } else if ($7 === 111) {
                    let _pipe = $xdh.public_key_from_der(spki_bytes);
                    let _pipe$1 = $result.map(
                      _pipe,
                      (var0) => { return new $x509.XdhPublicKey(var0); },
                    );
                    return $result.replace_error(
                      _pipe$1,
                      new $x509.Oid(alg_oid),
                    );
                  } else if ($7 === 112) {
                    let _pipe = $eddsa.public_key_from_der(spki_bytes);
                    let _pipe$1 = $result.map(
                      _pipe,
                      (var0) => { return new $x509.EdPublicKey(var0); },
                    );
                    return $result.replace_error(
                      _pipe$1,
                      new $x509.Oid(alg_oid),
                    );
                  } else if ($7 === 113) {
                    let _pipe = $eddsa.public_key_from_der(spki_bytes);
                    let _pipe$1 = $result.map(
                      _pipe,
                      (var0) => { return new $x509.EdPublicKey(var0); },
                    );
                    return $result.replace_error(
                      _pipe$1,
                      new $x509.Oid(alg_oid),
                    );
                  } else {
                    return new Error(new $x509.Oid(alg_oid));
                  }
                } else {
                  return new Error(new $x509.Oid(alg_oid));
                }
              } else {
                return new Error(new $x509.Oid(alg_oid));
              }
            } else {
              return new Error(new $x509.Oid(alg_oid));
            }
          } else {
            let $4 = $3.tail;
            if ($4 instanceof $Empty) {
              return new Error(new $x509.Oid(alg_oid));
            } else {
              let $5 = $4.tail;
              if ($5 instanceof $Empty) {
                let $6 = alg_oid.head;
                if ($6 === 1) {
                  let $7 = $.head;
                  if ($7 === 2) {
                    let $8 = $1.head;
                    if ($8 === 840) {
                      let $9 = $2.head;
                      if ($9 === 10045) {
                        let $10 = $3.head;
                        if ($10 === 2) {
                          let $11 = $4.head;
                          if ($11 === 1) {
                            let _pipe = $ec.public_key_from_der(spki_bytes);
                            let _pipe$1 = $result.map(
                              _pipe,
                              (var0) => { return new $x509.EcPublicKey(var0); },
                            );
                            return $result.replace_error(
                              _pipe$1,
                              new $x509.Oid(alg_oid),
                            );
                          } else {
                            return new Error(new $x509.Oid(alg_oid));
                          }
                        } else {
                          return new Error(new $x509.Oid(alg_oid));
                        }
                      } else {
                        return new Error(new $x509.Oid(alg_oid));
                      }
                    } else {
                      return new Error(new $x509.Oid(alg_oid));
                    }
                  } else {
                    return new Error(new $x509.Oid(alg_oid));
                  }
                } else {
                  return new Error(new $x509.Oid(alg_oid));
                }
              } else {
                let $6 = $5.tail;
                if ($6 instanceof $Empty) {
                  let $7 = alg_oid.head;
                  if ($7 === 1) {
                    let $8 = $.head;
                    if ($8 === 2) {
                      let $9 = $1.head;
                      if ($9 === 840) {
                        let $10 = $2.head;
                        if ($10 === 113549) {
                          let $11 = $3.head;
                          if ($11 === 1) {
                            let $12 = $4.head;
                            if ($12 === 1) {
                              let $13 = $5.head;
                              if ($13 === 1) {
                                let _pipe = $rsa.public_key_from_der(
                                  spki_bytes,
                                  new $rsa.Spki(),
                                );
                                let _pipe$1 = $result.map(
                                  _pipe,
                                  (var0) => {
                                    return new $x509.RsaPublicKey(var0);
                                  },
                                );
                                return $result.replace_error(
                                  _pipe$1,
                                  new $x509.Oid(alg_oid),
                                );
                              } else {
                                return new Error(new $x509.Oid(alg_oid));
                              }
                            } else {
                              return new Error(new $x509.Oid(alg_oid));
                            }
                          } else {
                            return new Error(new $x509.Oid(alg_oid));
                          }
                        } else {
                          return new Error(new $x509.Oid(alg_oid));
                        }
                      } else {
                        return new Error(new $x509.Oid(alg_oid));
                      }
                    } else {
                      return new Error(new $x509.Oid(alg_oid));
                    }
                  } else {
                    return new Error(new $x509.Oid(alg_oid));
                  }
                } else {
                  return new Error(new $x509.Oid(alg_oid));
                }
              }
            }
          }
        }
      }
    }
  }
}

/**
 * Parse a public key from DER-encoded SubjectPublicKeyInfo.
 *
 * Decodes the algorithm identifier and dispatches to the appropriate key parser (RSA, EC, Ed25519, etc.).
 * Returns Error with the unknown OID if the algorithm is not supported.
 */
export function parse_public_key(spki_bytes) {
  let _block;
  let _pipe = $result.try$(
    $der.parse_sequence(spki_bytes),
    (_use0) => {
      let spki_content = _use0[0];
      return $result.try$(
        $der.parse_sequence(spki_content),
        (_use0) => {
          let alg_id_bytes = _use0[0];
          let after_alg = _use0[1];
          return $result.try$(
            $der.parse_oid(alg_id_bytes),
            (_use0) => {
              let alg_oid = _use0[0];
              return $result.try$(
                $der.parse_bit_string(after_alg),
                (_) => { return new Ok(alg_oid); },
              );
            },
          );
        },
      );
    },
  );
  _block = $result.replace_error(_pipe, new $x509.Oid(toList([])));
  let result = _block;
  let _pipe$1 = result;
  return $result.try$(
    _pipe$1,
    (_capture) => { return dispatch_public_key_parse(_capture, spki_bytes); },
  );
}

/**
 * Parse a single Subject Alternative Name entry.
 *
 * Decodes one GeneralName from DER encoding (DNS name, email, IP address, etc.).
 * Returns Error(Nil) if the entry is malformed.
 * When is_critical is True, unknown GeneralName types return Error.
 */
export function parse_general_name(bytes, is_critical) {
  return $result.try$(
    $der.parse_tlv(bytes),
    (_use0) => {
      let tag = _use0[0];
      let value = _use0[1];
      let rest = _use0[2];
      if (tag === 160) {
        return $result.try$(
          $der.parse_oid(value),
          (_use0) => {
            let oid_components = _use0[0];
            let after_oid = _use0[1];
            return $result.try$(
              $der.parse_context_tag(after_oid, 0),
              (_use0) => {
                let other_value = _use0[0];
                return new Ok(
                  [
                    new $x509.OtherName(
                      new $x509.Oid(oid_components),
                      other_value,
                    ),
                    rest,
                  ],
                );
              },
            );
          },
        );
      } else if (tag === 129) {
        let _pipe = $bit_array.to_string(value);
        return $result.map(_pipe, (s) => { return [new $x509.Email(s), rest]; });
      } else if (tag === 130) {
        let _pipe = $bit_array.to_string(value);
        return $result.map(
          _pipe,
          (s) => { return [new $x509.DnsName(s), rest]; },
        );
      } else if (tag === 164) {
        return $result.try$(
          $der.parse_sequence(value),
          (_use0) => {
            let name_content = _use0[0];
            let remaining = _use0[1];
            return $bool.guard(
              !isEqual(remaining, toBitArray([])),
              new Error(undefined),
              () => {
                return $result.try$(
                  parse_name(name_content),
                  (name) => {
                    return new Ok([new $x509.DirectoryName(name), rest]);
                  },
                );
              },
            );
          },
        );
      } else if (tag === 134) {
        let _pipe = $bit_array.to_string(value);
        return $result.map(_pipe, (s) => { return [new $x509.Uri(s), rest]; });
      } else if (tag === 135) {
        return new Ok([new $x509.IpAddress(value), rest]);
      } else if (tag === 136) {
        return $result.try$(
          $der.decode_oid_components(value),
          (oid_components) => {
            return new Ok(
              [new $x509.RegisteredId(new $x509.Oid(oid_components)), rest],
            );
          },
        );
      } else {
        if (is_critical) {
          return new Error(undefined);
        } else {
          return new Ok([new $x509.Unknown(tag, value), rest]);
        }
      }
    },
  );
}

/**
 * Recursively parse a sequence of Subject Alternative Name entries.
 *
 * Accumulates SAN entries from DER-encoded GeneralNames structure.
 * Returns Error(Nil) if parsing fails for any entry.
 * When is_critical is True, unknown GeneralName types cause an error.
 */
export function parse_general_names(bytes, acc, is_critical) {
  if (bytes.bitSize === 0) {
    return new Ok($list.reverse(acc));
  } else {
    return $result.try$(
      parse_general_name(bytes, is_critical),
      (_use0) => {
        let san = _use0[0];
        let rest = _use0[1];
        return parse_general_names(rest, listPrepend(san, acc), is_critical);
      },
    );
  }
}

/**
 * Encode a single Subject Alternative Name entry to DER format.
 *
 * Produces a context-specific tagged value for supported GeneralName types:
 * DNS names, email addresses, IP addresses, URIs, directory names,
 * registered IDs, and otherName entries.
 * Returns Error(Nil) for Unknown SAN types.
 */
export function encode_general_name(san) {
  if (san instanceof $x509.DnsName) {
    let name = san[0];
    return $der.encode_context_primitive_tag(2, $bit_array.from_string(name));
  } else if (san instanceof $x509.IpAddress) {
    let ip = san[0];
    return $der.encode_context_primitive_tag(7, ip);
  } else if (san instanceof $x509.Email) {
    let email = san[0];
    return $der.encode_context_primitive_tag(1, $bit_array.from_string(email));
  } else if (san instanceof $x509.Uri) {
    let uri = san[0];
    return $der.encode_context_primitive_tag(6, $bit_array.from_string(uri));
  } else if (san instanceof $x509.DirectoryName) {
    let name = san[0];
    return $result.try$(
      encode_name(name),
      (encoded_name) => { return $der.encode_context_tag(4, encoded_name); },
    );
  } else if (san instanceof $x509.RegisteredId) {
    let components = san[0].components;
    return $result.try$(
      $der.encode_oid(components),
      (oid_encoded) => {
        return $result.try$(
          $der.parse_tlv(oid_encoded),
          (_use0) => {
            let oid_content = _use0[1];
            return $der.encode_context_primitive_tag(8, oid_content);
          },
        );
      },
    );
  } else if (san instanceof $x509.OtherName) {
    let value = san.value;
    let oid_components = san.oid.components;
    return $result.try$(
      $der.encode_oid(oid_components),
      (oid_encoded) => {
        return $result.try$(
          $der.encode_context_tag(0, value),
          (value_tagged) => {
            let content = $bit_array.concat(toList([oid_encoded, value_tagged]));
            return $der.encode_context_tag(0, content);
          },
        );
      },
    );
  } else {
    return new Error(undefined);
  }
}

/**
 * Parse a single X.509 extension from DER encoding.
 *
 * Extracts the extension OID, critical flag, and DER-encoded value bytes.
 * Returns Error(Nil) if the extension structure is invalid.
 */
export function parse_single_extension(bytes) {
  return $result.try$(
    $der.parse_oid(bytes),
    (_use0) => {
      let oid_components = _use0[0];
      let after_oid = _use0[1];
      let _block;
      if (
        after_oid.bitSize >= 8 &&
        after_oid.byteAt(0) === 1 &&
        after_oid.bitSize >= 16 &&
        after_oid.byteAt(1) === 1 &&
        after_oid.bitSize >= 24
      ) {
        let critical_byte = after_oid.byteAt(2);
        let rest = bitArraySlice(after_oid, 24);
        _block = [critical_byte !== 0, rest];
      } else {
        let other = after_oid;
        _block = [false, other];
      }
      let $ = _block;
      let is_critical = $[0];
      let after_critical = $[1];
      return $result.try$(
        $der.parse_octet_string(after_critical),
        (_use0) => {
          let value = _use0[0];
          let remaining = _use0[1];
          return $bool.guard(
            !isEqual(remaining, toBitArray([])),
            new Error(undefined),
            () => {
              return new Ok([new $x509.Oid(oid_components), is_critical, value]);
            },
          );
        },
      );
    },
  );
}

/**
 * Parse a Subject Alternative Name extension from DER-encoded bytes.
 *
 * Decodes the extension value containing a GeneralNames sequence.
 * Returns Error(Nil) if the extension format is invalid.
 * When is_critical is True, unknown GeneralName types return Error.
 */
export function parse_san_extension(bytes, is_critical) {
  return $result.try$(
    $der.parse_sequence(bytes),
    (_use0) => {
      let san_content = _use0[0];
      return parse_general_names(san_content, toList([]), is_critical);
    },
  );
}

/**
 * Encode an X.509 AlgorithmIdentifier to DER format.
 *
 * Produces a DER SEQUENCE with OID and optional NULL parameters (for RSA signatures).
 * Returns Error(Nil) if OID encoding fails.
 */
export function encode_algorithm_identifier(sig_alg) {
  let oid = sig_alg.oid;
  let include_null_params = sig_alg.include_null_params;
  let components = oid.components;
  return $result.try$(
    $der.encode_oid(components),
    (oid_encoded) => {
      if (include_null_params) {
        return $der.encode_sequence(
          $bit_array.concat(toList([oid_encoded, toBitArray([5, 0])])),
        );
      } else {
        return $der.encode_sequence(oid_encoded);
      }
    },
  );
}

/**
 * Extract raw public key bytes from a SubjectPublicKeyInfo structure.
 *
 * Skips the algorithm identifier and returns only the BIT STRING key data.
 * Returns Error(Nil) if the SPKI structure is invalid.
 */
export function extract_spki_public_key_bytes(spki) {
  return $result.try$(
    $der.parse_sequence(spki),
    (_use0) => {
      let spki_content = _use0[0];
      return $result.try$(
        $der.parse_sequence(spki_content),
        (_use0) => {
          let after_alg = _use0[1];
          return $result.try$(
            $der.parse_bit_string(after_alg),
            (_use0) => {
              let pub_key_bytes = _use0[0];
              return new Ok(pub_key_bytes);
            },
          );
        },
      );
    },
  );
}

function extract_pem_body(
  loop$lines,
  loop$in_body,
  loop$acc,
  loop$begin_marker,
  loop$end_marker
) {
  while (true) {
    let lines = loop$lines;
    let in_body = loop$in_body;
    let acc = loop$acc;
    let begin_marker = loop$begin_marker;
    let end_marker = loop$end_marker;
    if (lines instanceof $Empty) {
      if (in_body) {
        return new Error(new PemMalformed());
      } else {
        return new Error(new PemNotFound());
      }
    } else if (in_body) {
      let line = lines.head;
      let rest = lines.tail;
      let $ = $string.starts_with(line, end_marker);
      if ($) {
        return new Ok([$list.reverse(acc), rest]);
      } else {
        loop$lines = rest;
        loop$in_body = true;
        loop$acc = listPrepend(line, acc);
        loop$begin_marker = begin_marker;
        loop$end_marker = end_marker;
      }
    } else {
      let line = lines.head;
      let rest = lines.tail;
      let $ = $string.starts_with(line, begin_marker);
      if ($) {
        loop$lines = rest;
        loop$in_body = true;
        loop$acc = acc;
        loop$begin_marker = begin_marker;
        loop$end_marker = end_marker;
      } else {
        loop$lines = rest;
        loop$in_body = false;
        loop$acc = acc;
        loop$begin_marker = begin_marker;
        loop$end_marker = end_marker;
      }
    }
  }
}

function extract_all_pem_bodies(
  loop$lines,
  loop$begin_marker,
  loop$end_marker,
  loop$acc
) {
  while (true) {
    let lines = loop$lines;
    let begin_marker = loop$begin_marker;
    let end_marker = loop$end_marker;
    let acc = loop$acc;
    let $ = extract_pem_body(lines, false, toList([]), begin_marker, end_marker);
    if ($ instanceof Ok) {
      let body = $[0][0];
      let remaining = $[0][1];
      loop$lines = remaining;
      loop$begin_marker = begin_marker;
      loop$end_marker = end_marker;
      loop$acc = listPrepend(body, acc);
    } else {
      let $1 = $[0];
      if ($1 instanceof PemNotFound) {
        return new Ok($list.reverse(acc));
      } else {
        return new Error(undefined);
      }
    }
  }
}

/**
 * Decode all PEM blocks matching the given markers to DER bytes.
 *
 * Returns all matching blocks in order. Returns Ok([]) if no blocks found.
 * Returns Error(Nil) if any block has invalid base64.
 */
export function decode_pem_all(pem, begin_marker, end_marker) {
  let lines = $string.split(pem, "\n");
  let lines$1 = $list.map(lines, $string.trim);
  return $result.try$(
    extract_all_pem_bodies(lines$1, begin_marker, end_marker, toList([])),
    (blocks) => {
      return $list.try_map(
        blocks,
        (body_lines) => {
          let body = $string.join(body_lines, "");
          return $bit_array.base64_decode(body);
        },
      );
    },
  );
}

/**
 * Decode PEM-encoded data to DER bytes.
 *
 * Extracts base64 data between begin and end markers and decodes to binary.
 * Returns Error(Nil) if markers are not found or base64 decoding fails.
 */
export function decode_pem(pem, begin_marker, end_marker) {
  let _pipe = decode_pem_all(pem, begin_marker, end_marker);
  return $result.try$(_pipe, $list.first);
}

/**
 * Encode DER bytes to PEM format with the specified markers.
 *
 * Produces a base64-encoded string wrapped in the given begin and end markers,
 * with lines wrapped at 64 characters per RFC 7468.
 */
export function encode_pem(der, begin_marker, end_marker) {
  let encoded = $bit_array.base64_encode(der, true);
  let _block;
  let _pipe = $utils.chunk_string(encoded, 64);
  _block = $list.map(_pipe, (line) => { return line + "\n"; });
  let lines = _block;
  let _pipe$1 = $string_tree.new$();
  let _pipe$2 = $string_tree.append(_pipe$1, begin_marker + "\n");
  let _pipe$3 = $string_tree.append_tree(
    _pipe$2,
    $string_tree.from_strings(lines),
  );
  let _pipe$4 = $string_tree.append(_pipe$3, end_marker + "\n\n");
  return $string_tree.to_string(_pipe$4);
}

/**
 * Encode a Subject Alternative Name extension to DER format.
 *
 * Produces a DER-encoded extension structure with OID, optional critical flag,
 * and the encoded GeneralNames sequence.
 * Returns Error(Nil) if encoding fails (e.g., Unknown SAN types).
 */
export function encode_san_extension(sans, critical) {
  let oid_components = toList([2, 5, 29, 17]);
  return $result.try$(
    $der.encode_oid(oid_components),
    (oid_encoded) => {
      let _pipe = sans;
      let _pipe$1 = $list.reverse(_pipe);
      let _pipe$2 = $list.try_map(_pipe$1, encode_general_name);
      let _pipe$3 = $result.map(_pipe$2, $bit_array.concat);
      let _pipe$4 = $result.try$(_pipe$3, $der.encode_sequence);
      let _pipe$5 = $result.try$(_pipe$4, $der.encode_octet_string);
      let _pipe$6 = $result.map(
        _pipe$5,
        (value_octet) => {
          if (critical) {
            return $bit_array.concat(
              toList([oid_encoded, $der.encode_bool(true), value_octet]),
            );
          } else {
            return $bit_array.concat(toList([oid_encoded, value_octet]));
          }
        },
      );
      return $result.try$(_pipe$6, $der.encode_sequence);
    },
  );
}
