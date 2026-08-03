import * as $crypto from "../../../gleam_crypto/gleam/crypto.mjs";
import * as $bit_array from "../../../gleam_stdlib/gleam/bit_array.mjs";
import { CustomType as $CustomType } from "../../gleam.mjs";

export class Pkce extends $CustomType {
  constructor(verifier, challenge) {
    super();
    this.verifier = verifier;
    this.challenge = challenge;
  }
}
export const Pkce$Pkce = (verifier, challenge) => new Pkce(verifier, challenge);
export const Pkce$isPkce = (value) => value instanceof Pkce;
export const Pkce$Pkce$verifier = (value) => value.verifier;
export const Pkce$Pkce$0 = (value) => value.verifier;
export const Pkce$Pkce$challenge = (value) => value.challenge;
export const Pkce$Pkce$1 = (value) => value.challenge;

function b64(bits) {
  return $bit_array.base64_url_encode(bits, false);
}

export function generate() {
  let verifier = b64($crypto.strong_random_bytes(32));
  let challenge = b64(
    $crypto.hash(
      $crypto.HashAlgorithm$Sha256$const,
      $bit_array.from_string(verifier),
    ),
  );
  return new Pkce(verifier, challenge);
}
