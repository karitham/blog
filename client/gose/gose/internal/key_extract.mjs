import * as $rsa from "../../../kryptos/kryptos/rsa.mjs";
import { Ok, Error } from "../../gleam.mjs";
import * as $gose from "../../gose.mjs";

export function rsa_private_key(material) {
  if (material instanceof $gose.Rsa) {
    let $ = material[0];
    if ($ instanceof $gose.RsaPrivate) {
      let private$ = $.key;
      return new Ok(private$);
    } else {
      return new Error(undefined);
    }
  } else {
    return new Error(undefined);
  }
}

export function rsa_public_key(material) {
  if (material instanceof $gose.Rsa) {
    let $ = material[0];
    if ($ instanceof $gose.RsaPrivate) {
      let public$ = $.public;
      return new Ok(public$);
    } else {
      let public$ = $.key;
      return new Ok(public$);
    }
  } else {
    return new Error(undefined);
  }
}
