import * as $bit_array from "../../../gleam_stdlib/gleam/bit_array.mjs";
import * as $bool from "../../../gleam_stdlib/gleam/bool.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
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
} from "../../gleam.mjs";
import * as $ec from "../../kryptos/ec.mjs";
import * as $ecdsa from "../../kryptos/ecdsa.mjs";
import * as $eddsa from "../../kryptos/eddsa.mjs";
import * as $hash from "../../kryptos/hash.mjs";
import * as $der from "../../kryptos/internal/der.mjs";
import * as $utils from "../../kryptos/internal/utils.mjs";
import * as $x509_internal from "../../kryptos/internal/x509.mjs";
import * as $rsa from "../../kryptos/rsa.mjs";
import * as $x509 from "../../kryptos/x509.mjs";

const FILEPATH = "src/kryptos/x509/csr.gleam";

class BuiltCsr extends $CustomType {
  constructor(der) {
    super();
    this.der = der;
  }
}

class ParsedCsr extends $CustomType {
  constructor(der, version, subject, public_key, signature_algorithm, subject_alt_names, extensions, attributes) {
    super();
    this.der = der;
    this.version = version;
    this.subject = subject;
    this.public_key = public_key;
    this.signature_algorithm = signature_algorithm;
    this.subject_alt_names = subject_alt_names;
    this.extensions = extensions;
    this.attributes = attributes;
  }
}

export class InvalidPem extends $CustomType {}
export const CsrError$InvalidPem = () => new InvalidPem();
export const CsrError$isInvalidPem = (value) => value instanceof InvalidPem;

export class InvalidStructure extends $CustomType {}
export const CsrError$InvalidStructure = () => new InvalidStructure();
export const CsrError$isInvalidStructure = (value) =>
  value instanceof InvalidStructure;

export class UnsupportedSignatureAlgorithm extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const CsrError$UnsupportedSignatureAlgorithm = ($0) =>
  new UnsupportedSignatureAlgorithm($0);
export const CsrError$isUnsupportedSignatureAlgorithm = (value) =>
  value instanceof UnsupportedSignatureAlgorithm;
export const CsrError$UnsupportedSignatureAlgorithm$0 = (value) => value[0];

export class UnsupportedKeyType extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const CsrError$UnsupportedKeyType = ($0) => new UnsupportedKeyType($0);
export const CsrError$isUnsupportedKeyType = (value) =>
  value instanceof UnsupportedKeyType;
export const CsrError$UnsupportedKeyType$0 = (value) => value[0];

export class SignatureVerificationFailed extends $CustomType {}
export const CsrError$SignatureVerificationFailed = () =>
  new SignatureVerificationFailed();
export const CsrError$isSignatureVerificationFailed = (value) =>
  value instanceof SignatureVerificationFailed;

export class UnsupportedVersion extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const CsrError$UnsupportedVersion = ($0) => new UnsupportedVersion($0);
export const CsrError$isUnsupportedVersion = (value) =>
  value instanceof UnsupportedVersion;
export const CsrError$UnsupportedVersion$0 = (value) => value[0];

class Builder extends $CustomType {
  constructor(subject, extensions) {
    super();
    this.subject = subject;
    this.extensions = extensions;
  }
}

const oid_extension_request = /* @__PURE__ */ new $x509.Oid(
  /* @__PURE__ */ toList([1, 2, 840, 113_549, 1, 9, 14]),
);

const pem_end = "-----END CERTIFICATE REQUEST-----";

const pem_begin = "-----BEGIN CERTIFICATE REQUEST-----";

const pem_new_end = "-----END NEW CERTIFICATE REQUEST-----";

const pem_new_begin = "-----BEGIN NEW CERTIFICATE REQUEST-----";

/**
 * Creates a new CSR builder with an empty subject and no extensions.
 *
 * Use the `with_*` functions to configure the builder, then call
 * `sign_with_ecdsa` or `sign_with_rsa` to generate the signed CSR.
 */
export function new$() {
  return new Builder($x509.name(toList([])), new $x509.Extensions(toList([])));
}

/**
 * Sets the distinguished name subject for the CSR.
 */
export function with_subject(builder, subject) {
  return new Builder(subject, builder.extensions);
}

/**
 * Adds a DNS name to the Subject Alternative Names extension.
 *
 * SANs allow a certificate to be valid for multiple hostnames. Modern
 * browsers require the domain to appear in the SAN extension, not just
 * the Common Name. The name must contain only ASCII characters.
 */
export function with_dns_name(builder, name) {
  return $bool.guard(
    !$utils.is_ascii(name),
    new Error(undefined),
    () => {
      let $ = builder.extensions;
      let sans = $.subject_alt_names;
      return new Ok(
        new Builder(
          builder.subject,
          new $x509.Extensions(listPrepend(new $x509.DnsName(name), sans)),
        ),
      );
    },
  );
}

/**
 * Adds an email address to the Subject Alternative Names extension.
 *
 * Used for S/MIME certificates. The email must contain only ASCII characters.
 */
export function with_email(builder, email) {
  return $bool.guard(
    !$utils.is_ascii(email),
    new Error(undefined),
    () => {
      let $ = builder.extensions;
      let sans = $.subject_alt_names;
      return new Ok(
        new Builder(
          builder.subject,
          new $x509.Extensions(listPrepend(new $x509.Email(email), sans)),
        ),
      );
    },
  );
}

/**
 * Adds an IP address to the Subject Alternative Names extension.
 *
 * Accepts IPv4 (e.g., "192.168.1.1") or IPv6 (e.g., "2001:db8::1") addresses.
 */
export function with_ip(builder, ip) {
  return $result.try$(
    $utils.parse_ip(ip),
    (parsed) => {
      let $ = builder.extensions;
      let sans = $.subject_alt_names;
      return new Ok(
        new Builder(
          builder.subject,
          new $x509.Extensions(listPrepend(new $x509.IpAddress(parsed), sans)),
        ),
      );
    },
  );
}

function encode_csr(cert_request_info, sig_alg, signature) {
  return $result.try$(
    $x509_internal.encode_algorithm_identifier(sig_alg),
    (sig_alg_der) => {
      return $result.try$(
        $der.encode_bit_string(signature),
        (sig_bits) => {
          return $der.encode_sequence(
            $bit_array.concat(
              toList([cert_request_info, sig_alg_der, sig_bits]),
            ),
          );
        },
      );
    },
  );
}

function encode_extensions(extensions) {
  let sans = extensions.subject_alt_names;
  let _pipe = $x509_internal.encode_san_extension(sans, false);
  return $result.try$(_pipe, $der.encode_sequence);
}

function encode_extension_request(extensions) {
  let $ = oid_extension_request;
  let ext_req_components = $.components;
  return $result.try$(
    $der.encode_oid(ext_req_components),
    (oid_encoded) => {
      let _pipe = extensions;
      let _pipe$1 = encode_extensions(_pipe);
      let _pipe$2 = $result.try$(_pipe$1, $der.encode_set);
      let _pipe$3 = $result.map(
        _pipe$2,
        (set_encoded) => {
          return $bit_array.concat(toList([oid_encoded, set_encoded]));
        },
      );
      return $result.try$(_pipe$3, $der.encode_sequence);
    },
  );
}

function encode_attributes(extensions) {
  let $ = $list.is_empty(extensions.subject_alt_names);
  if ($) {
    return $der.encode_context_tag(0, toBitArray([]));
  } else {
    let _pipe = extensions;
    let _pipe$1 = encode_extension_request(_pipe);
    return $result.try$(
      _pipe$1,
      (_capture) => { return $der.encode_context_tag(0, _capture); },
    );
  }
}

function encode_certification_request_info(builder, spki) {
  return $result.try$(
    $der.encode_integer(toBitArray([0])),
    (version) => {
      return $result.try$(
        $x509_internal.encode_name(builder.subject),
        (subject) => {
          return $result.try$(
            encode_attributes(builder.extensions),
            (attributes) => {
              return $der.encode_sequence(
                $bit_array.concat(toList([version, subject, spki, attributes])),
              );
            },
          );
        },
      );
    },
  );
}

/**
 * Signs the CSR with an ECDSA private key.
 *
 * The public key is derived from the private key and included in the CSR.
 * Recommended hash: `Sha256` for P-256, `Sha384` for P-384, `Sha512` for
 * P-521. `Sha1` is supported for legacy compatibility but is
 * cryptographically weak.
 */
export function sign_with_ecdsa(builder, key, hash) {
  return $result.try$(
    $x509_internal.ecdsa_sig_alg_info(hash),
    (sig_alg) => {
      let public_key$1 = $ec.public_key_from_private_key(key);
      return $result.try$(
        $ec.public_key_to_der(public_key$1),
        (spki) => {
          return $result.try$(
            encode_certification_request_info(builder, spki),
            (cert_request_info) => {
              let signature = $ecdsa.sign(key, cert_request_info, hash);
              return $result.try$(
                encode_csr(cert_request_info, sig_alg, signature),
                (csr_der) => { return new Ok(new BuiltCsr(csr_der)); },
              );
            },
          );
        },
      );
    },
  );
}

/**
 * Signs the CSR with an RSA private key using PKCS#1 v1.5 padding.
 *
 * The public key is derived from the private key and included in the CSR.
 * Recommended hash: `Sha256` for 2048-bit keys, `Sha384` or `Sha512` for
 * 3072-bit or larger keys. `Sha1` is supported for legacy compatibility
 * but is cryptographically weak.
 */
export function sign_with_rsa(builder, key, hash) {
  return $result.try$(
    $x509_internal.rsa_sig_alg_info(hash),
    (sig_alg) => {
      let public_key$1 = $rsa.public_key_from_private_key(key);
      return $result.try$(
        $rsa.public_key_to_der(public_key$1, new $rsa.Spki()),
        (spki) => {
          return $result.try$(
            encode_certification_request_info(builder, spki),
            (cert_request_info) => {
              let signature = $rsa.sign(
                key,
                cert_request_info,
                hash,
                new $rsa.Pkcs1v15(),
              );
              return $result.try$(
                encode_csr(cert_request_info, sig_alg, signature),
                (csr_der) => { return new Ok(new BuiltCsr(csr_der)); },
              );
            },
          );
        },
      );
    },
  );
}

/**
 * Signs the CSR with an EdDSA private key (Ed25519 or Ed448).
 *
 * **Note**: Support for EdDSA is limited with browsers and certificate
 * authorities.
 */
export function sign_with_eddsa(builder, key) {
  let sig_alg = $x509_internal.eddsa_sig_alg_info($eddsa.curve(key));
  let public_key$1 = $eddsa.public_key_from_private_key(key);
  return $result.try$(
    $eddsa.public_key_to_der(public_key$1),
    (spki) => {
      return $result.try$(
        encode_certification_request_info(builder, spki),
        (cert_request_info) => {
          let signature = $eddsa.sign(key, cert_request_info);
          return $result.try$(
            encode_csr(cert_request_info, sig_alg, signature),
            (csr_der) => { return new Ok(new BuiltCsr(csr_der)); },
          );
        },
      );
    },
  );
}

/**
 * Exports the CSR as DER-encoded bytes.
 */
export function to_der(csr) {
  if (csr instanceof BuiltCsr) {
    let der = csr.der;
    return der;
  } else {
    let der = csr.der;
    return der;
  }
}

/**
 * Exports the CSR as a PEM-encoded string.
 *
 * This is the format typically required when submitting a CSR to a
 * Certificate Authority.
 */
export function to_pem(csr) {
  return $x509_internal.encode_pem(to_der(csr), pem_begin, pem_end);
}

function verify_signature(csr) {
  let der;
  let public_key$1;
  let signature_algorithm$1;
  if (csr instanceof ParsedCsr) {
    der = csr.der;
    public_key$1 = csr.public_key;
    signature_algorithm$1 = csr.signature_algorithm;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "kryptos/x509/csr",
      536,
      "verify_signature",
      "Pattern match failed, no pattern matched the value.",
      {
        value: csr,
        start: 16508,
        end: 16579,
        pattern_start: 16519,
        pattern_end: 16573
      }
    )
  }
  return $result.try$(
    (() => {
      let _pipe = $der.parse_sequence(der);
      return $result.replace_error(_pipe, new InvalidStructure());
    })(),
    (_use0) => {
      let csr_content = _use0[0];
      return $result.try$(
        (() => {
          let _pipe = $x509_internal.parse_sequence_with_header(csr_content);
          return $result.replace_error(_pipe, new InvalidStructure());
        })(),
        (_use0) => {
          let cert_req_info_bytes = _use0[0];
          let after_info = _use0[1];
          return $result.try$(
            (() => {
              let _pipe = $der.parse_sequence(after_info);
              return $result.replace_error(_pipe, new InvalidStructure());
            })(),
            (_use0) => {
              let after_sig_alg = _use0[1];
              return $result.try$(
                (() => {
                  let _pipe = $der.parse_bit_string(after_sig_alg);
                  return $result.replace_error(_pipe, new InvalidStructure());
                })(),
                (_use0) => {
                  let signature = _use0[0];
                  let verified = $x509_internal.verify_signature(
                    public_key$1,
                    cert_req_info_bytes,
                    signature,
                    signature_algorithm$1,
                  );
                  if (verified) {
                    return new Ok(undefined);
                  } else {
                    return new Error(new SignatureVerificationFailed());
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

function parse_extensions(bytes, sans, exts) {
  if (bytes.bitSize === 0) {
    return new Ok([sans, $list.reverse(exts)]);
  } else {
    return $result.try$(
      $der.parse_sequence(bytes),
      (_use0) => {
        let ext_bytes = _use0[0];
        let rest = _use0[1];
        return $result.try$(
          $x509_internal.parse_single_extension(ext_bytes),
          (_use0) => {
            let oid = _use0[0];
            let is_critical = _use0[1];
            let value = _use0[2];
            let $ = oid.components;
            if ($ instanceof $Empty) {
              return parse_extensions(
                rest,
                sans,
                listPrepend([oid, is_critical, value], exts),
              );
            } else {
              let $1 = $.tail;
              if ($1 instanceof $Empty) {
                return parse_extensions(
                  rest,
                  sans,
                  listPrepend([oid, is_critical, value], exts),
                );
              } else {
                let $2 = $1.tail;
                if ($2 instanceof $Empty) {
                  return parse_extensions(
                    rest,
                    sans,
                    listPrepend([oid, is_critical, value], exts),
                  );
                } else {
                  let $3 = $2.tail;
                  if ($3 instanceof $Empty) {
                    return parse_extensions(
                      rest,
                      sans,
                      listPrepend([oid, is_critical, value], exts),
                    );
                  } else {
                    let $4 = $3.tail;
                    if ($4 instanceof $Empty) {
                      let $5 = $.head;
                      if ($5 === 2) {
                        let $6 = $1.head;
                        if ($6 === 5) {
                          let $7 = $2.head;
                          if ($7 === 29) {
                            let $8 = $3.head;
                            if ($8 === 17) {
                              return $result.try$(
                                $x509_internal.parse_san_extension(value, false),
                                (new_sans) => {
                                  return parse_extensions(
                                    rest,
                                    $list.append(sans, new_sans),
                                    exts,
                                  );
                                },
                              );
                            } else {
                              return parse_extensions(
                                rest,
                                sans,
                                listPrepend([oid, is_critical, value], exts),
                              );
                            }
                          } else {
                            return parse_extensions(
                              rest,
                              sans,
                              listPrepend([oid, is_critical, value], exts),
                            );
                          }
                        } else {
                          return parse_extensions(
                            rest,
                            sans,
                            listPrepend([oid, is_critical, value], exts),
                          );
                        }
                      } else {
                        return parse_extensions(
                          rest,
                          sans,
                          listPrepend([oid, is_critical, value], exts),
                        );
                      }
                    } else {
                      return parse_extensions(
                        rest,
                        sans,
                        listPrepend([oid, is_critical, value], exts),
                      );
                    }
                  }
                }
              }
            }
          },
        );
      },
    );
  }
}

function parse_extension_request(bytes) {
  return $bool.guard(
    $bit_array.byte_size(bytes) === 0,
    new Ok([toList([]), toList([])]),
    () => {
      return $result.try$(
        $der.parse_sequence(bytes),
        (_use0) => {
          let exts_content = _use0[0];
          return parse_extensions(exts_content, toList([]), toList([]));
        },
      );
    },
  );
}

function parse_single_attribute(bytes) {
  return $result.try$(
    $der.parse_oid(bytes),
    (_use0) => {
      let oid_components = _use0[0];
      let after_oid = _use0[1];
      return $result.try$(
        $der.parse_set(after_oid),
        (_use0) => {
          let value = _use0[0];
          let remaining = _use0[1];
          return $bool.guard(
            !isEqual(remaining, toBitArray([])),
            new Error(undefined),
            () => { return new Ok([new $x509.Oid(oid_components), value]); },
          );
        },
      );
    },
  );
}

function parse_attributes_content(bytes, sans, exts, attrs) {
  if (bytes.bitSize === 0) {
    return new Ok([sans, $list.reverse(exts), $list.reverse(attrs)]);
  } else {
    return $result.try$(
      $der.parse_sequence(bytes),
      (_use0) => {
        let attr_bytes = _use0[0];
        let rest = _use0[1];
        return $result.try$(
          parse_single_attribute(attr_bytes),
          (_use0) => {
            let oid = _use0[0];
            let value = _use0[1];
            let $ = oid.components;
            if ($ instanceof $Empty) {
              return parse_attributes_content(
                rest,
                sans,
                exts,
                listPrepend([oid, value], attrs),
              );
            } else {
              let $1 = $.tail;
              if ($1 instanceof $Empty) {
                return parse_attributes_content(
                  rest,
                  sans,
                  exts,
                  listPrepend([oid, value], attrs),
                );
              } else {
                let $2 = $1.tail;
                if ($2 instanceof $Empty) {
                  return parse_attributes_content(
                    rest,
                    sans,
                    exts,
                    listPrepend([oid, value], attrs),
                  );
                } else {
                  let $3 = $2.tail;
                  if ($3 instanceof $Empty) {
                    return parse_attributes_content(
                      rest,
                      sans,
                      exts,
                      listPrepend([oid, value], attrs),
                    );
                  } else {
                    let $4 = $3.tail;
                    if ($4 instanceof $Empty) {
                      return parse_attributes_content(
                        rest,
                        sans,
                        exts,
                        listPrepend([oid, value], attrs),
                      );
                    } else {
                      let $5 = $4.tail;
                      if ($5 instanceof $Empty) {
                        return parse_attributes_content(
                          rest,
                          sans,
                          exts,
                          listPrepend([oid, value], attrs),
                        );
                      } else {
                        let $6 = $5.tail;
                        if ($6 instanceof $Empty) {
                          return parse_attributes_content(
                            rest,
                            sans,
                            exts,
                            listPrepend([oid, value], attrs),
                          );
                        } else {
                          let $7 = $6.tail;
                          if ($7 instanceof $Empty) {
                            let $8 = $.head;
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
                                      if ($13 === 9) {
                                        let $14 = $6.head;
                                        if ($14 === 14) {
                                          return $result.try$(
                                            parse_extension_request(value),
                                            (_use0) => {
                                              let new_sans = _use0[0];
                                              let new_exts = _use0[1];
                                              return parse_attributes_content(
                                                rest,
                                                $list.append(sans, new_sans),
                                                $list.append(exts, new_exts),
                                                attrs,
                                              );
                                            },
                                          );
                                        } else {
                                          return parse_attributes_content(
                                            rest,
                                            sans,
                                            exts,
                                            listPrepend([oid, value], attrs),
                                          );
                                        }
                                      } else {
                                        return parse_attributes_content(
                                          rest,
                                          sans,
                                          exts,
                                          listPrepend([oid, value], attrs),
                                        );
                                      }
                                    } else {
                                      return parse_attributes_content(
                                        rest,
                                        sans,
                                        exts,
                                        listPrepend([oid, value], attrs),
                                      );
                                    }
                                  } else {
                                    return parse_attributes_content(
                                      rest,
                                      sans,
                                      exts,
                                      listPrepend([oid, value], attrs),
                                    );
                                  }
                                } else {
                                  return parse_attributes_content(
                                    rest,
                                    sans,
                                    exts,
                                    listPrepend([oid, value], attrs),
                                  );
                                }
                              } else {
                                return parse_attributes_content(
                                  rest,
                                  sans,
                                  exts,
                                  listPrepend([oid, value], attrs),
                                );
                              }
                            } else {
                              return parse_attributes_content(
                                rest,
                                sans,
                                exts,
                                listPrepend([oid, value], attrs),
                              );
                            }
                          } else {
                            return parse_attributes_content(
                              rest,
                              sans,
                              exts,
                              listPrepend([oid, value], attrs),
                            );
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          },
        );
      },
    );
  }
}

function parse_attributes(bytes) {
  if (bytes.bitSize >= 8 && bytes.byteAt(0) === 160) {
    let $ = $der.parse_context_tag(bytes, 0);
    if ($ instanceof Ok) {
      let attrs_content = $[0][0];
      return parse_attributes_content(
        attrs_content,
        toList([]),
        toList([]),
        toList([]),
      );
    } else {
      return new Error(undefined);
    }
  } else {
    return new Ok([toList([]), toList([]), toList([])]);
  }
}

function parse_version(bytes) {
  if (bytes.bitSize === 8) {
    if (bytes.byteAt(0) === 0) {
      return new Ok(0);
    } else {
      let v = bytes.byteAt(0);
      return new Error(new UnsupportedVersion(v));
    }
  } else {
    return new Error(new InvalidStructure());
  }
}

/**
 * Parse a DER-encoded CSR without verifying the signature.
 *
 * Useful for debugging malformed or partially valid CSRs.
 * The parsed fields may not be trustworthy since the signature
 * was not verified.
 */
export function from_der_unverified(der) {
  return $result.try$(
    (() => {
      let _pipe = $der.parse_sequence(der);
      return $result.replace_error(_pipe, new InvalidStructure());
    })(),
    (_use0) => {
      let csr_content = _use0[0];
      let remaining = _use0[1];
      return $bool.guard(
        $bit_array.byte_size(remaining) !== 0,
        new Error(new InvalidStructure()),
        () => {
          return $result.try$(
            (() => {
              let _pipe = $x509_internal.parse_sequence_with_header(csr_content);
              return $result.replace_error(_pipe, new InvalidStructure());
            })(),
            (_use0) => {
              let cert_req_info_bytes = _use0[0];
              let after_info = _use0[1];
              return $result.try$(
                (() => {
                  let _pipe = $der.parse_sequence(cert_req_info_bytes);
                  return $result.replace_error(_pipe, new InvalidStructure());
                })(),
                (_use0) => {
                  let cert_req_info_content = _use0[0];
                  return $result.try$(
                    (() => {
                      let _pipe = $der.parse_integer(cert_req_info_content);
                      return $result.replace_error(
                        _pipe,
                        new InvalidStructure(),
                      );
                    })(),
                    (_use0) => {
                      let version_bytes = _use0[0];
                      let after_version = _use0[1];
                      return $result.try$(
                        parse_version(version_bytes),
                        (version) => {
                          return $result.try$(
                            (() => {
                              let _pipe = $der.parse_sequence(after_version);
                              return $result.replace_error(
                                _pipe,
                                new InvalidStructure(),
                              );
                            })(),
                            (_use0) => {
                              let subject_bytes = _use0[0];
                              let after_subject = _use0[1];
                              return $result.try$(
                                (() => {
                                  let _pipe = $x509_internal.parse_name(
                                    subject_bytes,
                                  );
                                  return $result.replace_error(
                                    _pipe,
                                    new InvalidStructure(),
                                  );
                                })(),
                                (subject) => {
                                  return $result.try$(
                                    (() => {
                                      let _pipe = $x509_internal.parse_sequence_with_header(
                                        after_subject,
                                      );
                                      return $result.replace_error(
                                        _pipe,
                                        new InvalidStructure(),
                                      );
                                    })(),
                                    (_use0) => {
                                      let spki_bytes = _use0[0];
                                      let after_spki = _use0[1];
                                      return $result.try$(
                                        (() => {
                                          let _pipe = $x509_internal.parse_public_key(
                                            spki_bytes,
                                          );
                                          return $result.map_error(
                                            _pipe,
                                            (oid) => {
                                              let $ = oid.components;
                                              if ($ instanceof $Empty) {
                                                return new InvalidStructure();
                                              } else {
                                                return new UnsupportedKeyType(
                                                  oid,
                                                );
                                              }
                                            },
                                          );
                                        })(),
                                        (public_key) => {
                                          return $result.try$(
                                            (() => {
                                              let _pipe = parse_attributes(
                                                after_spki,
                                              );
                                              return $result.replace_error(
                                                _pipe,
                                                new InvalidStructure(),
                                              );
                                            })(),
                                            (_use0) => {
                                              let subject_alt_names$1 = _use0[0];
                                              let extensions$1 = _use0[1];
                                              let attributes$1 = _use0[2];
                                              return $result.try$(
                                                (() => {
                                                  let _pipe = $der.parse_sequence(
                                                    after_info,
                                                  );
                                                  return $result.replace_error(
                                                    _pipe,
                                                    new InvalidStructure(),
                                                  );
                                                })(),
                                                (_use0) => {
                                                  let sig_alg_bytes = _use0[0];
                                                  let after_sig_alg = _use0[1];
                                                  return $result.try$(
                                                    (() => {
                                                      let _pipe = $x509_internal.parse_signature_algorithm(
                                                        sig_alg_bytes,
                                                      );
                                                      return $result.map_error(
                                                        _pipe,
                                                        (var0) => {
                                                          return new UnsupportedSignatureAlgorithm(
                                                            var0,
                                                          );
                                                        },
                                                      );
                                                    })(),
                                                    (signature_algorithm) => {
                                                      return $result.try$(
                                                        (() => {
                                                          let _pipe = $der.parse_bit_string(
                                                            after_sig_alg,
                                                          );
                                                          return $result.replace_error(
                                                            _pipe,
                                                            new InvalidStructure(),
                                                          );
                                                        })(),
                                                        (_use0) => {
                                                          
                                                          return new Ok(
                                                            new ParsedCsr(
                                                              der,
                                                              version,
                                                              subject,
                                                              public_key,
                                                              signature_algorithm,
                                                              subject_alt_names$1,
                                                              extensions$1,
                                                              attributes$1,
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
        },
      );
    },
  );
}

/**
 * Parse a DER-encoded CSR and verify its signature.
 */
export function from_der(der) {
  return $result.try$(
    from_der_unverified(der),
    (parsed) => {
      return $result.try$(
        verify_signature(parsed),
        (_) => { return new Ok(parsed); },
      );
    },
  );
}

function decode_csr_pem(pem) {
  let $ = $x509_internal.decode_pem(pem, pem_begin, pem_end);
  if ($ instanceof Ok) {
    return $;
  } else {
    return $x509_internal.decode_pem(pem, pem_new_begin, pem_new_end);
  }
}

/**
 * Parse a PEM-encoded CSR and verify its signature.
 *
 * Returns an error if the PEM is invalid, the structure is malformed,
 * or the signature doesn't verify against the embedded public key.
 */
export function from_pem(pem) {
  return $result.try$(
    (() => {
      let _pipe = decode_csr_pem(pem);
      return $result.replace_error(_pipe, new InvalidPem());
    })(),
    (der) => { return from_der(der); },
  );
}

/**
 * Parse a PEM-encoded CSR without verifying the signature.
 *
 * Useful for debugging malformed or partially valid CSRs.
 * The parsed fields may not be trustworthy.
 */
export function from_pem_unverified(pem) {
  return $result.try$(
    (() => {
      let _pipe = decode_csr_pem(pem);
      return $result.replace_error(_pipe, new InvalidPem());
    })(),
    (der) => { return from_der_unverified(der); },
  );
}

/**
 * Returns the version of a parsed CSR.
 *
 * PKCS#10 v1 CSRs always have version 0.
 */
export function version(csr) {
  let version$1;
  if (csr instanceof ParsedCsr) {
    version$1 = csr.version;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "kryptos/x509/csr",
      367,
      "version",
      "Pattern match failed, no pattern matched the value.",
      {
        value: csr,
        start: 11643,
        end: 11683,
        pattern_start: 11654,
        pattern_end: 11677
      }
    )
  }
  return version$1;
}

/**
 * Returns the subject (distinguished name) of a parsed CSR.
 */
export function subject(csr) {
  let subject$1;
  if (csr instanceof ParsedCsr) {
    subject$1 = csr.subject;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "kryptos/x509/csr",
      373,
      "subject",
      "Pattern match failed, no pattern matched the value.",
      {
        value: csr,
        start: 11809,
        end: 11849,
        pattern_start: 11820,
        pattern_end: 11843
      }
    )
  }
  return subject$1;
}

/**
 * Returns the public key embedded in a parsed CSR.
 */
export function public_key(csr) {
  let public_key$1;
  if (csr instanceof ParsedCsr) {
    public_key$1 = csr.public_key;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "kryptos/x509/csr",
      379,
      "public_key",
      "Pattern match failed, no pattern matched the value.",
      {
        value: csr,
        start: 11974,
        end: 12017,
        pattern_start: 11985,
        pattern_end: 12011
      }
    )
  }
  return public_key$1;
}

/**
 * Returns the signature algorithm used to sign the CSR.
 */
export function signature_algorithm(csr) {
  let signature_algorithm$1;
  if (csr instanceof ParsedCsr) {
    signature_algorithm$1 = csr.signature_algorithm;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "kryptos/x509/csr",
      385,
      "signature_algorithm",
      "Pattern match failed, no pattern matched the value.",
      {
        value: csr,
        start: 12168,
        end: 12220,
        pattern_start: 12179,
        pattern_end: 12214
      }
    )
  }
  return signature_algorithm$1;
}

/**
 * Returns the Subject Alternative Names from the CSR.
 */
export function subject_alt_names(csr) {
  let subject_alt_names$1;
  if (csr instanceof ParsedCsr) {
    subject_alt_names$1 = csr.subject_alt_names;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "kryptos/x509/csr",
      391,
      "subject_alt_names",
      "Pattern match failed, no pattern matched the value.",
      {
        value: csr,
        start: 12378,
        end: 12428,
        pattern_start: 12389,
        pattern_end: 12422
      }
    )
  }
  return subject_alt_names$1;
}

/**
 * Returns any extensions beyond SANs as raw (OID, critical, value) tuples.
 *
 * This allows access to extensions that kryptos doesn't have typed
 * representations for. The Bool indicates whether the extension was
 * marked as critical per RFC 5280.
 */
export function extensions(csr) {
  let extensions$1;
  if (csr instanceof ParsedCsr) {
    extensions$1 = csr.extensions;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "kryptos/x509/csr",
      401,
      "extensions",
      "Pattern match failed, no pattern matched the value.",
      {
        value: csr,
        start: 12786,
        end: 12829,
        pattern_start: 12797,
        pattern_end: 12823
      }
    )
  }
  return extensions$1;
}

/**
 * Returns any non-extension attributes as raw (OID, value) pairs.
 *
 * Most CSRs only have the extensionRequest attribute, so this is
 * typically empty.
 */
export function attributes(csr) {
  let attributes$1;
  if (csr instanceof ParsedCsr) {
    attributes$1 = csr.attributes;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "kryptos/x509/csr",
      410,
      "attributes",
      "Pattern match failed, no pattern matched the value.",
      {
        value: csr,
        start: 13077,
        end: 13120,
        pattern_start: 13088,
        pattern_end: 13114
      }
    )
  }
  return attributes$1;
}
