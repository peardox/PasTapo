unit Tapo.Crypto;

{
  Cryptography for the Tapo local protocols, in pure Pascal (RTL only):
  AES-128 (ECB block, CBC/PKCS#7, CCM), HMAC-SHA256, HKDF-SHA256,
  PBKDF2-HMAC-SHA256, P-256 arithmetic and the SPAKE2+ prover (RFC 9383).

  Ported from https://github.com/mihai-dinculescu/tapo and checked against
  the RFC 9383 test vector and the crate's known answers; run
  TapoCryptoSelfTest to repeat those checks in your build.
}

{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}

interface

uses
  System.SysUtils, System.Classes, System.Hash, System.NetEncoding;

type
  (***
    Raised when a cryptographic operation fails: a bad key length, invalid padding after
    decryption, or a device share that is not a point on P-256.

    Tapo.Client converts this to @link(ETapoError) where it arises during a login.
  *)
  /// <summary>
  ///   Raised when a cryptographic operation fails: a bad key length, invalid
  ///   padding after decryption, or a device share that is not a point on P-256.
  /// </summary>
  /// <remarks>
  ///   Tapo.Client converts this to <see cref="Tapo.Client|ETapoError"/> where
  ///   it arises during a login.
  /// </remarks>
  ETapoCryptoError = class(Exception);

  (***
    The prover's side of a completed SPAKE2+ exchange (RFC 9383), as returned by
    @link(SpakeProve).
  *)
  /// <summary>
  ///   The prover's side of a completed SPAKE2+ exchange (RFC 9383), as
  ///   returned by <see cref="SpakeProve"/>.
  /// </summary>
  TSpakeProof = record
    (*** The prover share X, uncompressed SEC1 (65 bytes). Sent to the device as user_share. *)
    /// <summary>The prover share X, uncompressed SEC1 (65 bytes). Sent to the device as user_share.</summary>
    Share: TBytes;
    (*** The prover confirmation MAC (32 bytes). Sent to the device as user_confirm. *)
    /// <summary>The prover confirmation MAC (32 bytes). Sent to the device as user_confirm.</summary>
    Confirm: TBytes;
    (***
      The session secret (32 bytes) from which the TPAP session key and nonce are derived.
    *)
    /// <summary>The session secret (32 bytes) from which the TPAP session key and nonce are derived.</summary>
    SharedKey: TBytes;
    (*** The key that checks the device's confirmation (dev_confirm). *)
    /// <summary>The key that checks the device's confirmation (dev_confirm).</summary>
    VerifierConfirmKey: TBytes;
  end;

{ Byte helpers }

(***
  Concatenates byte arrays.

  @param(Parts The arrays to join, in order. Empty arrays are allowed.)

  @returns(A new array holding every byte of Parts.)
*)
/// <summary>Concatenates byte arrays.</summary>
/// <param name="Parts">The arrays to join, in order. Empty arrays are allowed.</param>
/// <returns>A new array holding every byte of Parts.</returns>
function Cat(const Parts: array of TBytes): TBytes;

(***
  Encodes a 32-bit integer as 4 big-endian bytes.

  @param(V The value. Negative values are encoded in two's complement.)

  @returns(4 bytes, most significant first.)
*)
/// <summary>Encodes a 32-bit integer as 4 big-endian bytes.</summary>
/// <param name="V">The value. Negative values are encoded in two's complement.</param>
/// <returns>4 bytes, most significant first.</returns>
function Int32BE(V: Integer): TBytes;

(***
  Reads a 32-bit big-endian integer.

  @param(B The bytes to read from.)

  @param(Offset Index of the first of the 4 bytes.)

  @returns(The signed value.)
*)
/// <summary>Reads a 32-bit big-endian integer.</summary>
/// <param name="B">The bytes to read from.</param>
/// <param name="Offset">Index of the first of the 4 bytes.</param>
/// <returns>The signed value.</returns>
function ReadInt32BE(const B: TBytes; Offset: Integer): Integer;

(***
  Compares two byte arrays.

  @returns(True if both have the same length and content.)
*)
/// <summary>Compares two byte arrays.</summary>
/// <returns>True if both have the same length and content.</returns>
function BytesEqual(const A, B: TBytes): Boolean;

(*** Encodes a string as UTF-8. *)
/// <summary>Encodes a string as UTF-8.</summary>
function Utf8(const S: string): TBytes;

(***
  Formats bytes as lower-case hexadecimal.

  @returns(Two characters per byte, for example 'a1b2'.)
*)
/// <summary>Formats bytes as lower-case hexadecimal.</summary>
/// <returns>Two characters per byte, for example 'a1b2'.</returns>
function BytesToHex(const B: TBytes): string;

(***
  Parses hexadecimal text into bytes.

  @param(S An even number of hexadecimal digits, upper or lower case.)

  @raises(EConvertError S holds a character that is not a hexadecimal digit.)
*)
/// <summary>Parses hexadecimal text into bytes.</summary>
/// <param name="S">An even number of hexadecimal digits, upper or lower case.</param>
/// <exception cref="EConvertError">S holds a character that is not a hexadecimal digit.</exception>
function HexToBytes(const S: string): TBytes;

(***
  Returns cryptographically secure random bytes.

  Uses BCryptGenRandom on Windows and /dev/urandom elsewhere. If neither is available it falls
  back to @code(Random), which is not secure.

  @param(Count The number of bytes.)
*)
/// <summary>Returns cryptographically secure random bytes.</summary>
/// <param name="Count">The number of bytes.</param>
/// <remarks>
///   Uses BCryptGenRandom on Windows and /dev/urandom elsewhere. If neither
///   is available it falls back to <c>Random</c>, which is not secure.
/// </remarks>
function SecureRandomBytes(Count: Integer): TBytes;

(*** Encodes bytes as standard Base64 without line breaks. *)
/// <summary>Encodes bytes as standard Base64 without line breaks.</summary>
function Base64Encode(const B: TBytes): string;

(*** Decodes standard Base64. *)
/// <summary>Decodes standard Base64.</summary>
function Base64Decode(const S: string): TBytes;

{ Hashes and key derivation }

(***
  Computes the SHA-1 hash of A.

  @returns(20 bytes.)
*)
/// <summary>Computes the SHA-1 hash of A.</summary>
/// <returns>20 bytes.</returns>
function SHA1Of(const A: TBytes): TBytes;

(***
  Computes the SHA-256 hash of A.

  @returns(32 bytes.)
*)
/// <summary>Computes the SHA-256 hash of A.</summary>
/// <returns>32 bytes.</returns>
function SHA256Of(const A: TBytes): TBytes;

(***
  Computes the MD5 hash of A.

  @returns(16 bytes.)
*)
/// <summary>Computes the MD5 hash of A.</summary>
/// <returns>16 bytes.</returns>
function MD5Of(const A: TBytes): TBytes;

(***
  Computes HMAC-SHA256 (RFC 2104).

  @param(AKey The key, of any length.)

  @param(AData The message.)

  @returns(The 32-byte MAC.)
*)
/// <summary>Computes HMAC-SHA256 (RFC 2104).</summary>
/// <param name="AKey">The key, of any length.</param>
/// <param name="AData">The message.</param>
/// <returns>The 32-byte MAC.</returns>
function HMACSHA256(const AKey, AData: TBytes): TBytes;

(***
  Derives key material with HKDF-SHA256 (RFC 5869).

  @param(IKM The input key material.)

  @param(Salt The salt; empty means a string of zeros.)

  @param(Info Context information for the expand step.)

  @param(Len The number of bytes to derive, at most 8160.)

  @returns(Len bytes of output key material.)
*)
/// <summary>Derives key material with HKDF-SHA256 (RFC 5869).</summary>
/// <param name="IKM">The input key material.</param>
/// <param name="Salt">The salt; empty means a string of zeros.</param>
/// <param name="Info">Context information for the expand step.</param>
/// <param name="Len">The number of bytes to derive, at most 8160.</param>
/// <returns>Len bytes of output key material.</returns>
function HKDFSHA256(const IKM, Salt, Info: TBytes; Len: Integer): TBytes;

(***
  Derives a key with PBKDF2-HMAC-SHA256 (RFC 8018).

  @param(Password The password bytes.)

  @param(Salt The salt.)

  @param(Iterations The iteration count, at least 1.)

  @param(Len The number of bytes to derive.)

  @returns(Len bytes of derived key.)
*)
/// <summary>Derives a key with PBKDF2-HMAC-SHA256 (RFC 8018).</summary>
/// <param name="Password">The password bytes.</param>
/// <param name="Salt">The salt.</param>
/// <param name="Iterations">The iteration count, at least 1.</param>
/// <param name="Len">The number of bytes to derive.</param>
/// <returns>Len bytes of derived key.</returns>
function PBKDF2SHA256(const Password, Salt: TBytes; Iterations, Len: Integer): TBytes;

{ AES-128 }

(***
  Encrypts with AES-128 in CBC mode with PKCS#7 padding.

  @param(Key 16-byte key.)

  @param(IV 16-byte initialisation vector.)

  @param(Plain The plaintext, of any length.)

  @returns(The ciphertext, a multiple of 16 bytes.)

  @raises(ETapoCryptoError Key is not 16 bytes.)

  @seealso(AES128CBCDecrypt)
*)
/// <summary>Encrypts with AES-128 in CBC mode with PKCS#7 padding.</summary>
/// <param name="Key">16-byte key.</param>
/// <param name="IV">16-byte initialisation vector.</param>
/// <param name="Plain">The plaintext, of any length.</param>
/// <returns>The ciphertext, a multiple of 16 bytes.</returns>
/// <exception cref="ETapoCryptoError">Key is not 16 bytes.</exception>
/// <seealso cref="AES128CBCDecrypt"/>
function AES128CBCEncrypt(const Key, IV, Plain: TBytes): TBytes;

(***
  Decrypts AES-128 CBC and removes PKCS#7 padding.

  @param(Key 16-byte key.)

  @param(IV 16-byte initialisation vector.)

  @param(Cipher The ciphertext, a non-zero multiple of 16 bytes.)

  @returns(The plaintext.)

  @raises(ETapoCryptoError Cipher has the wrong length, or the padding is invalid @(usually a
  wrong key@).)

  @seealso(AES128CBCEncrypt)
*)
/// <summary>Decrypts AES-128 CBC and removes PKCS#7 padding.</summary>
/// <param name="Key">16-byte key.</param>
/// <param name="IV">16-byte initialisation vector.</param>
/// <param name="Cipher">The ciphertext, a non-zero multiple of 16 bytes.</param>
/// <returns>The plaintext.</returns>
/// <exception cref="ETapoCryptoError">
///   Cipher has the wrong length, or the padding is invalid (usually a wrong key).
/// </exception>
/// <seealso cref="AES128CBCEncrypt"/>
function AES128CBCDecrypt(const Key, IV, Cipher: TBytes): TBytes;

(***
  Encrypts with AES-128 in CCM mode with a 12-byte nonce, a 16-byte tag and no associated data, as
  TPAP sessions do.

  @param(Key 16-byte key.)

  @param(Nonce 12-byte nonce.)

  @param(Plain The plaintext, shorter than 16 MB.)

  @returns(The ciphertext followed by the 16-byte tag.)

  @seealso(AES128CCMDecrypt)
*)
/// <summary>
///   Encrypts with AES-128 in CCM mode with a 12-byte nonce, a 16-byte tag
///   and no associated data, as TPAP sessions do.
/// </summary>
/// <param name="Key">16-byte key.</param>
/// <param name="Nonce">12-byte nonce.</param>
/// <param name="Plain">The plaintext, shorter than 16 MB.</param>
/// <returns>The ciphertext followed by the 16-byte tag.</returns>
/// <seealso cref="AES128CCMDecrypt"/>
function AES128CCMEncrypt(const Key, Nonce, Plain: TBytes): TBytes;

(***
  Decrypts and authenticates AES-128 CCM (12-byte nonce, 16-byte tag).

  @param(Key 16-byte key.)

  @param(Nonce 12-byte nonce.)

  @param(Data The ciphertext followed by the 16-byte tag.)

  @param(Plain Receives the plaintext, or nil if authentication fails.)

  @returns(True if the tag is valid.)

  @seealso(AES128CCMEncrypt)
*)
/// <summary>Decrypts and authenticates AES-128 CCM (12-byte nonce, 16-byte tag).</summary>
/// <param name="Key">16-byte key.</param>
/// <param name="Nonce">12-byte nonce.</param>
/// <param name="Data">The ciphertext followed by the 16-byte tag.</param>
/// <param name="Plain">Receives the plaintext, or nil if authentication fails.</param>
/// <returns>True if the tag is valid.</returns>
/// <seealso cref="AES128CCMEncrypt"/>
function AES128CCMDecrypt(const Key, Nonce, Data: TBytes; out Plain: TBytes): Boolean;

{ SPAKE2+ }

(***
  Runs the prover side of SPAKE2+ (RFC 9383) on P-256 with SHA-256, HKDF-SHA256 and HMAC-SHA256,
  as the TPAP login does.

  @param(Credential The password transform the device asked for @(for plugs, the SHA-1 hex of the
  password@).)

  @param(Salt The device's dev_salt.)

  @param(Iterations The device's PBKDF2 iteration count.)

  @param(UserRandom The 32 random bytes sent in pake_register.)

  @param(DeviceRandom The device's 32-byte dev_random.)

  @param(DeviceShare The device's share @(dev_share@), a SEC1 point.)

  @returns(The share and confirmation to send, and the keys for the session.)

  @raises(ETapoCryptoError DeviceShare is not a usable point on P-256.)
*)
/// <summary>
///   Runs the prover side of SPAKE2+ (RFC 9383) on P-256 with SHA-256,
///   HKDF-SHA256 and HMAC-SHA256, as the TPAP login does.
/// </summary>
/// <param name="Credential">The password transform the device asked for (for plugs, the SHA-1 hex of the password).</param>
/// <param name="Salt">The device's dev_salt.</param>
/// <param name="Iterations">The device's PBKDF2 iteration count.</param>
/// <param name="UserRandom">The 32 random bytes sent in pake_register.</param>
/// <param name="DeviceRandom">The device's 32-byte dev_random.</param>
/// <param name="DeviceShare">The device's share (dev_share), a SEC1 point.</param>
/// <returns>The share and confirmation to send, and the keys for the session.</returns>
/// <exception cref="ETapoCryptoError">DeviceShare is not a usable point on P-256.</exception>
function SpakeProve(const Credential: string; const Salt: TBytes; Iterations: Integer;
  const UserRandom, DeviceRandom, DeviceShare: TBytes): TSpakeProof;

(***
  Runs known-answer tests of AES, AES-CCM, the hashes, PBKDF2 and SPAKE2+ (against the RFC 9383
  test vector). No network access.

  Run this once after building on a new compiler or platform.

  @param(AReport Receives one line per check, each starting OK or FAIL.)

  @returns(True if every check passed.)
*)
/// <summary>
///   Runs known-answer tests of AES, AES-CCM, the hashes, PBKDF2 and SPAKE2+
///   (against the RFC 9383 test vector). No network access.
/// </summary>
/// <param name="AReport">Receives one line per check, each starting OK or FAIL.</param>
/// <returns>True if every check passed.</returns>
/// <remarks>Run this once after building on a new compiler or platform.</remarks>
function TapoCryptoSelfTest(out AReport: string): Boolean;

implementation

{$IFDEF MSWINDOWS}
function BCryptGenRandom(hAlgorithm: Pointer; pbBuffer: Pointer; cbBuffer: Cardinal;
  dwFlags: Cardinal): Integer; stdcall; external 'bcrypt.dll' name 'BCryptGenRandom';
{$ENDIF}


{ ============================================================================ }
{ Byte helpers                                                                 }
{ ============================================================================ }

function Cat(const Parts: array of TBytes): TBytes;
var
  I, Len, P: Integer;
begin
  Len := 0;
  for I := Low(Parts) to High(Parts) do
    Inc(Len, Length(Parts[I]));
  SetLength(Result, Len);
  P := 0;
  for I := Low(Parts) to High(Parts) do
    if Length(Parts[I]) > 0 then
    begin
      Move(Parts[I][0], Result[P], Length(Parts[I]));
      Inc(P, Length(Parts[I]));
    end;
end;

function Int32BE(V: Integer): TBytes;
var
  C: Cardinal;
begin
  C := Cardinal(V);
  SetLength(Result, 4);
  Result[0] := Byte(C shr 24);
  Result[1] := Byte(C shr 16);
  Result[2] := Byte(C shr 8);
  Result[3] := Byte(C);
end;

function ReadInt32BE(const B: TBytes; Offset: Integer): Integer;
begin
  Result := Integer((Cardinal(B[Offset]) shl 24) or (Cardinal(B[Offset + 1]) shl 16) or
                    (Cardinal(B[Offset + 2]) shl 8) or Cardinal(B[Offset + 3]));
end;

function Int64LE(V: UInt64): TBytes;
var
  I: Integer;
begin
  SetLength(Result, 8);
  for I := 0 to 7 do
    Result[I] := Byte(V shr (8 * I));
end;

function BytesEqual(const A, B: TBytes): Boolean;
begin
  Result := (Length(A) = Length(B)) and
    ((Length(A) = 0) or CompareMem(@A[0], @B[0], Length(A)));
end;

function Utf8(const S: string): TBytes;
begin
  Result := TEncoding.UTF8.GetBytes(S);
end;

function BytesToHex(const B: TBytes): string;
const
  Digits: array[0..15] of Char = '0123456789abcdef';
var
  I: Integer;
begin
  SetLength(Result, Length(B) * 2);
  for I := 0 to High(B) do
  begin
    Result[I * 2 + 1] := Digits[B[I] shr 4];
    Result[I * 2 + 2] := Digits[B[I] and $F];
  end;
end;

function HexToBytes(const S: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(S) div 2);
  for I := 0 to High(Result) do
    Result[I] := Byte(StrToInt('$' + Copy(S, I * 2 + 1, 2)));
end;

function SHA1Of(const A: TBytes): TBytes;
var
  H: THashSHA1;
begin
  H := THashSHA1.Create;
  if Length(A) > 0 then
    H.Update(A);
  Result := H.HashAsBytes;
end;

function SHA256Of(const A: TBytes): TBytes;
var
  H: THashSHA2;
begin
  H := THashSHA2.Create(THashSHA2.TSHA2Version.SHA256);
  if Length(A) > 0 then
    H.Update(A);
  Result := H.HashAsBytes;
end;

function MD5Of(const A: TBytes): TBytes;
var
  H: THashMD5;
begin
  H := THashMD5.Create;
  if Length(A) > 0 then
    H.Update(A);
  Result := H.HashAsBytes;
end;

function SecureRandomBytes(Count: Integer): TBytes;
var
  I: Integer;
  OK: Boolean;
{$IFNDEF MSWINDOWS}
  F: TFileStream;
{$ENDIF}
begin
  SetLength(Result, Count);
  if Count = 0 then
    Exit;
{$IFDEF MSWINDOWS}
  // BCRYPT_USE_SYSTEM_PREFERRED_RNG = 2
  OK := BCryptGenRandom(nil, @Result[0], Count, 2) = 0;
{$ELSE}
  try
    F := TFileStream.Create('/dev/urandom', fmOpenRead or fmShareDenyNone);
    try
      OK := F.Read(Result[0], Count) = Count;
    finally
      F.Free;
    end;
  except
    OK := False;
  end;
{$ENDIF}
  if not OK then
    for I := 0 to Count - 1 do
      Result[I] := Byte(Random(256));
end;

function Base64Encode(const B: TBytes): string;
var
  Enc: TBase64Encoding;
begin
  Enc := TBase64Encoding.Create(0);   // 0 = no line breaks
  try
    Result := Enc.EncodeBytesToString(B);
  finally
    Enc.Free;
  end;
end;

function Base64Decode(const S: string): TBytes;
begin
  Result := TNetEncoding.Base64.DecodeStringToBytes(S);
end;

{ ============================================================================ }
{ HMAC-SHA256, HKDF-SHA256 (RFC 5869), PBKDF2-HMAC-SHA256 (RFC 8018)           }
{ ============================================================================ }

function HMACSHA256(const AKey, AData: TBytes): TBytes;
var
  K, IPad, OPad: TBytes;
  I: Integer;
begin
  if Length(AKey) > 64 then
    K := SHA256Of(AKey)
  else
    K := Copy(AKey);
  SetLength(K, 64);          // zero-pads
  SetLength(IPad, 64);
  SetLength(OPad, 64);
  for I := 0 to 63 do
  begin
    IPad[I] := K[I] xor $36;
    OPad[I] := K[I] xor $5C;
  end;
  Result := SHA256Of(Cat([OPad, SHA256Of(Cat([IPad, AData]))]));
end;

function HKDFSHA256(const IKM, Salt, Info: TBytes; Len: Integer): TBytes;
var
  PRK, T, Okm: TBytes;
  I: Integer;
begin
  PRK := HMACSHA256(Salt, IKM);
  Okm := nil;
  T := nil;
  I := 1;
  while Length(Okm) < Len do
  begin
    T := HMACSHA256(PRK, Cat([T, Info, TBytes.Create(Byte(I))]));
    Okm := Cat([Okm, T]);
    Inc(I);
  end;
  Result := Copy(Okm, 0, Len);
end;

// PBKDF2 calls HMAC with the same key thousands of times. The hash states
// after the key's inner and outer pads are computed once and copied (a
// THashSHA2 is a record, so assignment copies its state), which halves the
// hashing and avoids most allocations.
function PBKDF2SHA256(const Password, Salt: TBytes; Iterations, Len: Integer): TBytes;
var
  K, Pad, Okm, U, T: TBytes;
  InnerKey, OuterKey, H: THashSHA2;
  Block, It, J: Integer;
begin
  if Length(Password) > 64 then
    K := SHA256Of(Password)
  else
    K := Copy(Password);
  SetLength(K, 64);
  SetLength(Pad, 64);
  for J := 0 to 63 do
    Pad[J] := K[J] xor $36;
  InnerKey := THashSHA2.Create(THashSHA2.TSHA2Version.SHA256);
  InnerKey.Update(Pad);
  for J := 0 to 63 do
    Pad[J] := K[J] xor $5C;
  OuterKey := THashSHA2.Create(THashSHA2.TSHA2Version.SHA256);
  OuterKey.Update(Pad);

  Okm := nil;
  Block := 1;
  while Length(Okm) < Len do
  begin
    U := Cat([Salt, Int32BE(Block)]);
    for It := 1 to Iterations do
    begin
      H := InnerKey;
      H.Update(U);
      U := H.HashAsBytes;
      H := OuterKey;
      H.Update(U);
      U := H.HashAsBytes;
      if It = 1 then
        T := Copy(U)
      else
        for J := 0 to 31 do
          T[J] := T[J] xor U[J];
    end;
    Okm := Cat([Okm, T]);
    Inc(Block);
  end;
  Result := Copy(Okm, 0, Len);
end;

{ ============================================================================ }
{ AES-128 (FIPS-197), byte oriented. Tables are generated at start-up.         }
{ ============================================================================ }

type
  TAESBlock = array[0..15] of Byte;

  TAES128 = record
  private
    RK: array[0..175] of Byte;
  public
    procedure Init(const AKey: TBytes);
    procedure EncryptBlock(var S: TAESBlock);
    procedure DecryptBlock(var S: TAESBlock);
  end;

var
  SBox, InvSBox: array[0..255] of Byte;

function Rotl8(X: Byte; S: Integer): Byte; inline;
begin
  Result := Byte((X shl S) or (X shr (8 - S)));
end;

function GMul(A, B: Byte): Byte;
var
  R: Byte;
begin
  R := 0;
  while B <> 0 do
  begin
    if (B and 1) <> 0 then
      R := R xor A;
    if (A and $80) <> 0 then
      A := Byte((A shl 1) xor $1B)
    else
      A := Byte(A shl 1);
    B := B shr 1;
  end;
  Result := R;
end;

procedure InitAESTables;
var
  P, Q, X: Byte;
  I: Integer;
begin
  P := 1;
  Q := 1;
  repeat
    if (P and $80) <> 0 then
      P := Byte(P xor (P shl 1) xor $1B)
    else
      P := Byte(P xor (P shl 1));
    Q := Byte(Q xor (Q shl 1));
    Q := Byte(Q xor (Q shl 2));
    Q := Byte(Q xor (Q shl 4));
    if (Q and $80) <> 0 then
      Q := Q xor $09;
    X := Q xor Rotl8(Q, 1) xor Rotl8(Q, 2) xor Rotl8(Q, 3) xor Rotl8(Q, 4);
    SBox[P] := X xor $63;
  until P = 1;
  SBox[0] := $63;
  for I := 0 to 255 do
    InvSBox[SBox[I]] := Byte(I);
end;

procedure TAES128.Init(const AKey: TBytes);
var
  I, J: Integer;
  T: array[0..3] of Byte;
  B, RC: Byte;
begin
  if Length(AKey) <> 16 then
    raise ETapoCryptoError.Create('AES-128 key must be 16 bytes');
  Move(AKey[0], RK[0], 16);
  RC := 1;
  for I := 4 to 43 do
  begin
    for J := 0 to 3 do
      T[J] := RK[(I - 1) * 4 + J];
    if I mod 4 = 0 then
    begin
      B := T[0];
      T[0] := SBox[T[1]] xor RC;
      T[1] := SBox[T[2]];
      T[2] := SBox[T[3]];
      T[3] := SBox[B];
      RC := GMul(RC, 2);
    end;
    for J := 0 to 3 do
      RK[I * 4 + J] := RK[(I - 4) * 4 + J] xor T[J];
  end;
end;

procedure TAES128.EncryptBlock(var S: TAESBlock);
var
  R, I, C: Integer;
  T: TAESBlock;
  A0, A1, A2, A3: Byte;
begin
  for I := 0 to 15 do
    S[I] := S[I] xor RK[I];
  for R := 1 to 10 do
  begin
    for I := 0 to 15 do
      T[I] := SBox[S[I]];
    for I := 0 to 15 do
      S[I] := T[(I mod 4) + 4 * (((I div 4) + (I mod 4)) mod 4)];
    if R < 10 then
      for C := 0 to 3 do
      begin
        A0 := S[4 * C]; A1 := S[4 * C + 1]; A2 := S[4 * C + 2]; A3 := S[4 * C + 3];
        S[4 * C]     := GMul(A0, 2) xor GMul(A1, 3) xor A2 xor A3;
        S[4 * C + 1] := A0 xor GMul(A1, 2) xor GMul(A2, 3) xor A3;
        S[4 * C + 2] := A0 xor A1 xor GMul(A2, 2) xor GMul(A3, 3);
        S[4 * C + 3] := GMul(A0, 3) xor A1 xor A2 xor GMul(A3, 2);
      end;
    for I := 0 to 15 do
      S[I] := S[I] xor RK[16 * R + I];
  end;
end;

procedure TAES128.DecryptBlock(var S: TAESBlock);
var
  R, I, C: Integer;
  T: TAESBlock;
  A0, A1, A2, A3: Byte;
begin
  for I := 0 to 15 do
    S[I] := S[I] xor RK[160 + I];
  for R := 9 downto 0 do
  begin
    T := S;
    for I := 0 to 15 do
      S[I] := InvSBox[T[(I mod 4) + 4 * (((I div 4) - (I mod 4) + 4) mod 4)]];
    for I := 0 to 15 do
      S[I] := S[I] xor RK[16 * R + I];
    if R > 0 then
      for C := 0 to 3 do
      begin
        A0 := S[4 * C]; A1 := S[4 * C + 1]; A2 := S[4 * C + 2]; A3 := S[4 * C + 3];
        S[4 * C]     := GMul(A0, 14) xor GMul(A1, 11) xor GMul(A2, 13) xor GMul(A3, 9);
        S[4 * C + 1] := GMul(A0, 9)  xor GMul(A1, 14) xor GMul(A2, 11) xor GMul(A3, 13);
        S[4 * C + 2] := GMul(A0, 13) xor GMul(A1, 9)  xor GMul(A2, 14) xor GMul(A3, 11);
        S[4 * C + 3] := GMul(A0, 11) xor GMul(A1, 13) xor GMul(A2, 9)  xor GMul(A3, 14);
      end;
  end;
end;

{ --- AES-128-CBC with PKCS#7 (KLAP) --- }

function AES128CBCEncrypt(const Key, IV, Plain: TBytes): TBytes;
var
  AES: TAES128;
  Pad, I, J, N, Off: Integer;
  Data: TBytes;
  Prev, Blk: TAESBlock;
begin
  AES.Init(Key);
  Pad := 16 - (Length(Plain) mod 16);
  SetLength(Data, Length(Plain) + Pad);
  if Length(Plain) > 0 then
    Move(Plain[0], Data[0], Length(Plain));
  for I := Length(Plain) to High(Data) do
    Data[I] := Byte(Pad);

  SetLength(Result, Length(Data));
  Move(IV[0], Prev[0], 16);
  N := Length(Data) div 16;
  for I := 0 to N - 1 do
  begin
    Off := I * 16;
    Move(Data[Off], Blk[0], 16);
    for J := 0 to 15 do
      Blk[J] := Blk[J] xor Prev[J];
    AES.EncryptBlock(Blk);
    Move(Blk[0], Result[Off], 16);
    Prev := Blk;
  end;
end;

function AES128CBCDecrypt(const Key, IV, Cipher: TBytes): TBytes;
var
  AES: TAES128;
  I, J, N, Off, Pad: Integer;
  Prev, Blk, Ct: TAESBlock;
begin
  if (Length(Cipher) = 0) or (Length(Cipher) mod 16 <> 0) then
    raise ETapoCryptoError.Create('Ciphertext length is not a multiple of the AES block size');
  AES.Init(Key);
  SetLength(Result, Length(Cipher));
  Move(IV[0], Prev[0], 16);
  N := Length(Cipher) div 16;
  for I := 0 to N - 1 do
  begin
    Off := I * 16;
    Move(Cipher[Off], Ct[0], 16);
    Blk := Ct;
    AES.DecryptBlock(Blk);
    for J := 0 to 15 do
      Blk[J] := Blk[J] xor Prev[J];
    Move(Blk[0], Result[Off], 16);
    Prev := Ct;
  end;
  Pad := Result[High(Result)];
  if (Pad < 1) or (Pad > 16) then
    raise ETapoCryptoError.Create('Invalid padding in decrypted response (wrong key?)');
  for J := Length(Result) - Pad to High(Result) do
    if Result[J] <> Pad then
      raise ETapoCryptoError.Create('Invalid padding in decrypted response (wrong key?)');
  SetLength(Result, Length(Result) - Pad);
end;

{ --- AES-128-CCM, 12-byte nonce, 16-byte tag, no associated data (TPAP) --- }

// CBC-MAC over B0 and the zero-padded plaintext, before masking with S0.
function CCMRawTag(const AES: TAES128; const Nonce, Plain: TBytes): TAESBlock;
var
  X, Blk: TAESBlock;
  I, J, N, Len: Integer;
begin
  Len := Length(Plain);
  // B0: flags = 8 * ((16 - 2) div 2) + (L - 1) with L = 3  ->  $3A
  X[0] := $3A;
  Move(Nonce[0], X[1], 12);
  X[13] := Byte(Len shr 16);
  X[14] := Byte(Len shr 8);
  X[15] := Byte(Len);
  AES.EncryptBlock(X);
  I := 0;
  while I < Len do
  begin
    FillChar(Blk, SizeOf(Blk), 0);
    N := Len - I;
    if N > 16 then
      N := 16;
    Move(Plain[I], Blk[0], N);
    for J := 0 to 15 do
      X[J] := X[J] xor Blk[J];
    AES.EncryptBlock(X);
    Inc(I, 16);
  end;
  Result := X;
end;

function CCMCounterBlock(const AES: TAES128; const Nonce: TBytes; Counter: Integer): TAESBlock;
begin
  Result[0] := $02;   // L - 1
  Move(Nonce[0], Result[1], 12);
  Result[13] := Byte(Counter shr 16);
  Result[14] := Byte(Counter shr 8);
  Result[15] := Byte(Counter);
  AES.EncryptBlock(Result);
end;

// XOR Data with the CTR keystream starting at counter 1.
function CCMCtr(const AES: TAES128; const Nonce, Data: TBytes): TBytes;
var
  S: TAESBlock;
  I, J, N: Integer;
begin
  SetLength(Result, Length(Data));
  I := 0;
  while I < Length(Data) do
  begin
    S := CCMCounterBlock(AES, Nonce, I div 16 + 1);
    N := Length(Data) - I;
    if N > 16 then
      N := 16;
    for J := 0 to N - 1 do
      Result[I + J] := Data[I + J] xor S[J];
    Inc(I, 16);
  end;
end;

function AES128CCMEncrypt(const Key, Nonce, Plain: TBytes): TBytes;
var
  AES: TAES128;
  T, S0: TAESBlock;
  Tag: TBytes;
  J: Integer;
begin
  AES.Init(Key);
  T := CCMRawTag(AES, Nonce, Plain);
  S0 := CCMCounterBlock(AES, Nonce, 0);
  SetLength(Tag, 16);
  for J := 0 to 15 do
    Tag[J] := T[J] xor S0[J];
  Result := Cat([CCMCtr(AES, Nonce, Plain), Tag]);
end;

function AES128CCMDecrypt(const Key, Nonce, Data: TBytes; out Plain: TBytes): Boolean;
var
  AES: TAES128;
  T, S0: TAESBlock;
  J, CtLen: Integer;
  Diff: Byte;
begin
  Plain := nil;
  if Length(Data) < 16 then
    Exit(False);
  CtLen := Length(Data) - 16;
  AES.Init(Key);
  Plain := CCMCtr(AES, Nonce, Copy(Data, 0, CtLen));
  T := CCMRawTag(AES, Nonce, Plain);
  S0 := CCMCounterBlock(AES, Nonce, 0);
  Diff := 0;
  for J := 0 to 15 do
    Diff := Diff or ((T[J] xor S0[J]) xor Data[CtLen + J]);
  Result := Diff = 0;
  if not Result then
    Plain := nil;
end;

{ ============================================================================ }
{ 256-bit modular arithmetic: 8 x 32-bit little-endian limbs, Montgomery (CIOS) }
{ ============================================================================ }

type
  TU256 = array[0..7] of Cardinal;

  TModulus = record
    M, One, R2: TU256;      // modulus, R mod M, R^2 mod M  (R = 2^256)
    N0: Cardinal;           // -M^-1 mod 2^32
    procedure Init(const AM: TU256);
    function Add(const A, B: TU256): TU256;
    function Sub(const A, B: TU256): TU256;
    function Mul(const A, B: TU256): TU256;          // A * B / R mod M
    function ToMont(const A: TU256): TU256;
    function FromMont(const A: TU256): TU256;
    function Pow(const A, E: TU256): TU256;          // A Montgomery, E plain
    function Inv(const A: TU256): TU256;             // Montgomery in and out
    function ReduceWide(const B: TBytes): TU256;     // big-endian, <= 64 bytes
  end;

const
  U256Zero: TU256 = (0, 0, 0, 0, 0, 0, 0, 0);
  U256OneP: TU256 = (1, 0, 0, 0, 0, 0, 0, 0);
  U256Two:  TU256 = (2, 0, 0, 0, 0, 0, 0, 0);

function U256FromBE(const B: TBytes; Offset: Integer = 0): TU256;
var
  I, P: Integer;
begin
  for I := 0 to 7 do
  begin
    P := Offset + 28 - 4 * I;
    Result[I] := (Cardinal(B[P]) shl 24) or (Cardinal(B[P + 1]) shl 16) or
                 (Cardinal(B[P + 2]) shl 8) or Cardinal(B[P + 3]);
  end;
end;

function U256ToBE(const A: TU256): TBytes;
var
  I, P: Integer;
begin
  SetLength(Result, 32);
  for I := 0 to 7 do
  begin
    P := 28 - 4 * I;
    Result[P]     := Byte(A[I] shr 24);
    Result[P + 1] := Byte(A[I] shr 16);
    Result[P + 2] := Byte(A[I] shr 8);
    Result[P + 3] := Byte(A[I]);
  end;
end;

function U256FromHex(const S: string): TU256;
begin
  Result := U256FromBE(HexToBytes(S));
end;

function U256Cmp(const A, B: TU256): Integer;
var
  I: Integer;
begin
  for I := 7 downto 0 do
    if A[I] <> B[I] then
    begin
      if A[I] > B[I] then
        Exit(1)
      else
        Exit(-1);
    end;
  Result := 0;
end;

function U256IsZero(const A: TU256): Boolean;
begin
  Result := U256Cmp(A, U256Zero) = 0;
end;

function U256AddC(const A, B: TU256; out R: TU256): Cardinal;
var
  I: Integer;
  S: UInt64;
  C: Cardinal;
begin
  C := 0;
  for I := 0 to 7 do
  begin
    S := UInt64(A[I]) + B[I] + C;
    R[I] := Cardinal(S);
    C := Cardinal(S shr 32);
  end;
  Result := C;
end;

function U256SubB(const A, B: TU256; out R: TU256): Cardinal;
var
  I: Integer;
  D: Int64;
  Br: Cardinal;
begin
  Br := 0;
  for I := 0 to 7 do
  begin
    D := Int64(A[I]) - Int64(B[I]) - Int64(Br);
    if D < 0 then
    begin
      D := D + $100000000;
      Br := 1;
    end
    else
      Br := 0;
    R[I] := Cardinal(D);
  end;
  Result := Br;
end;

procedure TModulus.Init(const AM: TU256);
var
  Inv, T: Cardinal;
  K: Integer;
  R: TU256;
begin
  M := AM;
  // N0 = -M^-1 mod 2^32 (Newton iteration, M odd)
  Inv := 1;
  for K := 1 to 5 do
  begin
    T := Cardinal(UInt64(M[0]) * Inv);
    T := Cardinal(Int64(2) - Int64(T));
    Inv := Cardinal(UInt64(Inv) * T);
  end;
  N0 := Cardinal(UInt64(not Inv) + 1);
  // One = R mod M = 2^256 - M  (M > 2^255)
  U256SubB(U256Zero, M, One);
  // R2 = R^2 mod M: double R 256 times
  R := One;
  for K := 1 to 256 do
    R := Add(R, R);
  R2 := R;
end;

function TModulus.Add(const A, B: TU256): TU256;
var
  T: TU256;
begin
  if (U256AddC(A, B, Result) <> 0) or (U256Cmp(Result, M) >= 0) then
  begin
    U256SubB(Result, M, T);
    Result := T;
  end;
end;

function TModulus.Sub(const A, B: TU256): TU256;
var
  T: TU256;
begin
  if U256SubB(A, B, Result) <> 0 then
  begin
    U256AddC(Result, M, T);
    Result := T;
  end;
end;

function TModulus.Mul(const A, B: TU256): TU256;
var
  T: array[0..9] of Cardinal;
  I, J: Integer;
  S: UInt64;
  C, Q: Cardinal;
  R: TU256;
begin
  FillChar(T, SizeOf(T), 0);
  for I := 0 to 7 do
  begin
    C := 0;
    for J := 0 to 7 do
    begin
      S := UInt64(T[J]) + UInt64(A[J]) * B[I] + C;
      T[J] := Cardinal(S);
      C := Cardinal(S shr 32);
    end;
    S := UInt64(T[8]) + C;
    T[8] := Cardinal(S);
    T[9] := Cardinal(S shr 32);

    Q := Cardinal(UInt64(T[0]) * N0);
    S := UInt64(T[0]) + UInt64(Q) * M[0];
    C := Cardinal(S shr 32);
    for J := 1 to 7 do
    begin
      S := UInt64(T[J]) + UInt64(Q) * M[J] + C;
      T[J - 1] := Cardinal(S);
      C := Cardinal(S shr 32);
    end;
    S := UInt64(T[8]) + C;
    T[7] := Cardinal(S);
    C := Cardinal(S shr 32);
    T[8] := T[9] + C;
  end;
  for I := 0 to 7 do
    Result[I] := T[I];
  if (T[8] <> 0) or (U256Cmp(Result, M) >= 0) then
  begin
    U256SubB(Result, M, R);
    Result := R;
  end;
end;

function TModulus.ToMont(const A: TU256): TU256;
begin
  Result := Mul(A, R2);
end;

function TModulus.FromMont(const A: TU256): TU256;
begin
  Result := Mul(A, U256OneP);
end;

function TModulus.Pow(const A, E: TU256): TU256;
var
  I: Integer;
  Base, Bits, R: TU256;
begin
  Base := A;   // copies: A or E may alias Result
  Bits := E;
  R := One;
  for I := 255 downto 0 do
  begin
    R := Mul(R, R);
    if ((Bits[I shr 5] shr (I and 31)) and 1) <> 0 then
      R := Mul(R, Base);
  end;
  Result := R;
end;

function TModulus.Inv(const A: TU256): TU256;
var
  E: TU256;
begin
  U256SubB(M, U256Two, E);     // Fermat: A^(M-2)
  Result := Pow(A, E);
end;

function TModulus.ReduceWide(const B: TBytes): TU256;
var
  W: TBytes;
  Hi, Lo, H, T: TU256;
begin
  if Length(B) > 64 then
    raise ETapoCryptoError.Create('ReduceWide: more than 64 bytes');
  SetLength(W, 64);                       // zero filled
  if Length(B) > 0 then
    Move(B[0], W[64 - Length(B)], Length(B));
  Hi := U256FromBE(W, 0);
  Lo := U256FromBE(W, 32);
  H := Mul(Hi, R2);                       // Hi * 2^256 mod M
  if U256Cmp(Lo, M) >= 0 then
  begin
    U256SubB(Lo, M, T);
    Lo := T;
  end;
  Result := Add(H, Lo);
end;

{ ============================================================================ }
{ P-256 in affine coordinates (coordinates kept in Montgomery form)            }
{ ============================================================================ }

type
  TECPoint = record
    X, Y: TU256;
    Inf: Boolean;
  end;

var
  FP, FN: TModulus;          // field prime p and group order n
  CurveB: TU256;             // b, Montgomery form
  SqrtExp: TU256;            // (p + 1) / 4
  PointG, PointM, PointN: TECPoint;

function ECInfinity: TECPoint;
begin
  Result.X := U256Zero;
  Result.Y := U256Zero;
  Result.Inf := True;
end;

function ECDouble(const P: TECPoint): TECPoint;
var
  Num, L, X3: TU256;
begin
  if P.Inf or U256IsZero(P.Y) then
    Exit(ECInfinity);
  // lambda = 3(x^2 - 1) / 2y   (a = -3)
  Num := FP.Sub(FP.Mul(P.X, P.X), FP.One);
  Num := FP.Add(FP.Add(Num, Num), Num);
  L := FP.Mul(Num, FP.Inv(FP.Add(P.Y, P.Y)));
  X3 := FP.Sub(FP.Sub(FP.Mul(L, L), P.X), P.X);
  Result.Y := FP.Sub(FP.Mul(L, FP.Sub(P.X, X3)), P.Y);
  Result.X := X3;
  Result.Inf := False;
end;

function ECAdd(const P, Q: TECPoint): TECPoint;
var
  L, X3: TU256;
begin
  if P.Inf then
    Exit(Q);
  if Q.Inf then
    Exit(P);
  if U256Cmp(P.X, Q.X) = 0 then
  begin
    if U256Cmp(P.Y, Q.Y) = 0 then
      Exit(ECDouble(P));
    Exit(ECInfinity);
  end;
  L := FP.Mul(FP.Sub(Q.Y, P.Y), FP.Inv(FP.Sub(Q.X, P.X)));
  X3 := FP.Sub(FP.Sub(FP.Mul(L, L), P.X), Q.X);
  Result.Y := FP.Sub(FP.Mul(L, FP.Sub(P.X, X3)), P.Y);
  Result.X := X3;
  Result.Inf := False;
end;

function ECNeg(const P: TECPoint): TECPoint;
begin
  Result := P;
  if not P.Inf then
    Result.Y := FP.Sub(U256Zero, P.Y);
end;

{ Scalar multiplication works in Jacobian coordinates (x = X/Z^2,
  y = Y/Z^3), so it needs one field inversion at the end instead of one per
  step: about 35 times fewer field multiplications than affine. Formulas:
  dbl-2001-b (a = -3) and add-2007-bl from the Explicit-Formulas Database. }

type
  TJacPoint = record
    X, Y, Z: TU256;
    Inf: Boolean;
  end;

function JacInfinity: TJacPoint;
begin
  Result.X := U256Zero;
  Result.Y := U256Zero;
  Result.Z := U256Zero;
  Result.Inf := True;
end;

function JacDouble(const P: TJacPoint): TJacPoint;
var
  Delta, Gamma, Beta, Alpha, T, B4, B8, G8, YZ: TU256;
begin
  if P.Inf or U256IsZero(P.Y) then
    Exit(JacInfinity);
  Delta := FP.Mul(P.Z, P.Z);
  Gamma := FP.Mul(P.Y, P.Y);
  Beta := FP.Mul(P.X, Gamma);
  T := FP.Mul(FP.Sub(P.X, Delta), FP.Add(P.X, Delta));
  Alpha := FP.Add(FP.Add(T, T), T);                 // 3(X - Z^2)(X + Z^2)
  B4 := FP.Add(Beta, Beta);
  B4 := FP.Add(B4, B4);                             // 4 beta
  B8 := FP.Add(B4, B4);                             // 8 beta
  Result.X := FP.Sub(FP.Mul(Alpha, Alpha), B8);
  YZ := FP.Add(P.Y, P.Z);
  Result.Z := FP.Sub(FP.Sub(FP.Mul(YZ, YZ), Gamma), Delta);
  G8 := FP.Mul(Gamma, Gamma);
  G8 := FP.Add(G8, G8);
  G8 := FP.Add(G8, G8);
  G8 := FP.Add(G8, G8);                             // 8 gamma^2
  Result.Y := FP.Sub(FP.Mul(Alpha, FP.Sub(B4, Result.X)), G8);
  Result.Inf := False;
end;

function JacAdd(const P, Q: TJacPoint): TJacPoint;
var
  Z1Z1, Z2Z2, U1, U2, S1, S2, H, R, H2, I, J, V, S1J, Z12: TU256;
begin
  if P.Inf then
    Exit(Q);
  if Q.Inf then
    Exit(P);
  Z1Z1 := FP.Mul(P.Z, P.Z);
  Z2Z2 := FP.Mul(Q.Z, Q.Z);
  U1 := FP.Mul(P.X, Z2Z2);
  U2 := FP.Mul(Q.X, Z1Z1);
  S1 := FP.Mul(FP.Mul(P.Y, Q.Z), Z2Z2);
  S2 := FP.Mul(FP.Mul(Q.Y, P.Z), Z1Z1);
  H := FP.Sub(U2, U1);
  R := FP.Sub(S2, S1);
  if U256IsZero(H) then
  begin
    if U256IsZero(R) then
      Exit(JacDouble(P));                           // P = Q
    Exit(JacInfinity);                              // P = -Q
  end;
  H2 := FP.Add(H, H);
  I := FP.Mul(H2, H2);
  J := FP.Mul(H, I);
  R := FP.Add(R, R);
  V := FP.Mul(U1, I);
  Result.X := FP.Sub(FP.Sub(FP.Mul(R, R), J), FP.Add(V, V));
  S1J := FP.Mul(S1, J);
  Result.Y := FP.Sub(FP.Mul(R, FP.Sub(V, Result.X)), FP.Add(S1J, S1J));
  Z12 := FP.Add(P.Z, Q.Z);
  Result.Z := FP.Mul(FP.Sub(FP.Sub(FP.Mul(Z12, Z12), Z1Z1), Z2Z2), H);
  Result.Inf := False;
end;

function ECMul(const P: TECPoint; const K: TU256): TECPoint;
var
  I: Integer;
  Q, R: TJacPoint;
  Zi, Zi2: TU256;
begin
  if P.Inf then
    Exit(ECInfinity);
  Q.X := P.X;
  Q.Y := P.Y;
  Q.Z := FP.One;                                    // Montgomery 1
  Q.Inf := False;
  R := JacInfinity;
  for I := 255 downto 0 do
  begin
    R := JacDouble(R);
    if ((K[I shr 5] shr (I and 31)) and 1) <> 0 then
      R := JacAdd(R, Q);
  end;
  if R.Inf then
    Exit(ECInfinity);
  Zi := FP.Inv(R.Z);
  Zi2 := FP.Mul(Zi, Zi);
  Result.X := FP.Mul(R.X, Zi2);
  Result.Y := FP.Mul(FP.Mul(R.Y, Zi2), Zi);
  Result.Inf := False;
end;

// x^3 - 3x + b
function ECRhs(const X: TU256): TU256;
var
  X3: TU256;
begin
  X3 := FP.Add(FP.Add(X, X), X);
  Result := FP.Add(FP.Sub(FP.Mul(FP.Mul(X, X), X), X3), CurveB);
end;

// SEC1 decode, compressed (33 bytes) or uncompressed (65 bytes).
function ECDecode(const B: TBytes; out P: TECPoint): Boolean;
var
  X, Y, R: TU256;
begin
  Result := False;
  P := ECInfinity;
  if (Length(B) = 65) and (B[0] = 4) then
  begin
    X := U256FromBE(B, 1);
    Y := U256FromBE(B, 33);
    if (U256Cmp(X, FP.M) >= 0) or (U256Cmp(Y, FP.M) >= 0) then
      Exit;
    X := FP.ToMont(X);
    Y := FP.ToMont(Y);
    if U256Cmp(FP.Mul(Y, Y), ECRhs(X)) <> 0 then
      Exit;
  end
  else if (Length(B) = 33) and ((B[0] = 2) or (B[0] = 3)) then
  begin
    X := U256FromBE(B, 1);
    if U256Cmp(X, FP.M) >= 0 then
      Exit;
    X := FP.ToMont(X);
    R := ECRhs(X);
    Y := FP.Pow(R, SqrtExp);
    if U256Cmp(FP.Mul(Y, Y), R) <> 0 then
      Exit;
    R := FP.FromMont(Y);
    if (R[0] and 1) <> Cardinal(B[0] and 1) then
      Y := FP.Sub(U256Zero, Y);
  end
  else
    Exit;
  P.X := X;
  P.Y := Y;
  P.Inf := False;
  Result := True;
end;

function ECEncode(const P: TECPoint): TBytes;
begin
  Result := Cat([TBytes.Create(4), U256ToBE(FP.FromMont(P.X)), U256ToBE(FP.FromMont(P.Y))]);
end;

procedure InitP256;
begin
  FP.Init(U256FromHex('ffffffff00000001000000000000000000000000ffffffffffffffffffffffff'));
  FN.Init(U256FromHex('ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551'));
  CurveB := FP.ToMont(U256FromHex('5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b'));
  SqrtExp := U256FromHex('3fffffffc0000000400000000000000000000000400000000000000000000000');
  PointG.X := FP.ToMont(U256FromHex('6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296'));
  PointG.Y := FP.ToMont(U256FromHex('4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5'));
  PointG.Inf := False;
  // RFC 9383 M and N for P-256
  if not ECDecode(HexToBytes('02886e2f97ace46e55ba9dd7242579f2993b64e16ef3dcab95afd497333d8fa12f'), PointM) or
     not ECDecode(HexToBytes('03d8bbd6c639c62937b04d997f38c3770719c629d7014d49a24b4f98baa1292b49'), PointN) then
    raise ETapoCryptoError.Create('P-256 initialisation failed (M/N not on curve)');
end;

{ ============================================================================ }
{ SPAKE2+ prover (RFC 9383, P-256 / SHA-256 / HKDF-SHA256 / HMAC-SHA256)       }
{ ============================================================================ }


procedure DeriveW0W1(const Credential: string; const Salt: TBytes; Iterations: Integer;
  out W0, W1: TU256);
var
  K: TBytes;
begin
  K := PBKDF2SHA256(Utf8(Credential), Salt, Iterations, 80);
  W0 := FN.ReduceWide(Copy(K, 0, 40));
  W1 := FN.ReduceWide(Copy(K, 40, 40));
end;

function Transcript(const Items: array of TBytes): TBytes;
var
  I: Integer;
begin
  Result := nil;
  for I := Low(Items) to High(Items) do
    Result := Cat([Result, Int64LE(Length(Items[I])), Items[I]]);
end;

function SpakeProveWith(const W0, W1, X: TU256; const Context, ProverId, VerifierId,
  VerifierShare: TBytes): TSpakeProof;
var
  Share, VS, Unmasked, Z, V: TECPoint;
  ShareB, VSB, MainKey, CK: TBytes;
begin
  Share := ECAdd(ECMul(PointG, X), ECMul(PointM, W0));
  if not ECDecode(VerifierShare, VS) then
    raise ETapoCryptoError.Create('The device''s share (dev_share) is not a point on P-256');
  Unmasked := ECAdd(VS, ECNeg(ECMul(PointN, W0)));
  Z := ECMul(Unmasked, X);
  V := ECMul(Unmasked, W1);
  if Z.Inf or V.Inf then
    raise ETapoCryptoError.Create('The device''s share (dev_share) leads to a key that is not secret');

  ShareB := ECEncode(Share);
  VSB := ECEncode(VS);
  MainKey := SHA256Of(Transcript([Context, ProverId, VerifierId,
    ECEncode(PointM), ECEncode(PointN), ShareB, VSB, ECEncode(Z), ECEncode(V),
    U256ToBE(W0)]));

  CK := HKDFSHA256(MainKey, nil, Utf8('ConfirmationKeys'), 64);
  Result.Share := ShareB;
  Result.Confirm := HMACSHA256(Copy(CK, 0, 32), VSB);
  Result.SharedKey := HKDFSHA256(MainKey, nil, Utf8('SharedKey'), 32);
  Result.VerifierConfirmKey := Copy(CK, 32, 32);
end;

function SpakeProve(const Credential: string; const Salt: TBytes; Iterations: Integer;
  const UserRandom, DeviceRandom, DeviceShare: TBytes): TSpakeProof;
var
  W0, W1, X: TU256;
  Context: TBytes;
begin
  DeriveW0W1(Credential, Salt, Iterations, W0, W1);
  repeat
    X := FN.ReduceWide(SecureRandomBytes(32));
  until not U256IsZero(X);
  Context := SHA256Of(Cat([Utf8('PAKE V1'), UserRandom, DeviceRandom]));
  Result := SpakeProveWith(W0, W1, X, Context, nil, nil, DeviceShare);
end;

{ ============================================================================ }
{ Self test (known-answer vectors; no network)                                 }
{ ============================================================================ }

function TapoCryptoSelfTest(out AReport: string): Boolean;
var
  Lines: TStringList;
  AllOK: Boolean;

  procedure Check(const AName: string; AOK: Boolean);
  begin
    if AOK then
      Lines.Add('OK    ' + AName)
    else
    begin
      Lines.Add('FAIL  ' + AName);
      AllOK := False;
    end;
  end;

var
  AES: TAES128;
  Blk: TAESBlock;
  Key, Out1, Plain, Body, SharedKey, Nonce, BaseNonce: TBytes;
  W0, W1: TU256;
  Proof: TSpakeProof;
  PG: TECPoint;
  I: Integer;
begin
  Lines := TStringList.Create;
  AllOK := True;
  try
    try
      // AES-128 (FIPS-197 C.1)
      AES.Init(HexToBytes('000102030405060708090a0b0c0d0e0f'));
      Out1 := HexToBytes('00112233445566778899aabbccddeeff');
      Move(Out1[0], Blk[0], 16);
      AES.EncryptBlock(Blk);
      SetLength(Out1, 16);
      Move(Blk[0], Out1[0], 16);
      Check('AES-128 encrypt', BytesToHex(Out1) = '69c4e0d86a7b0430d8cdb78070b4c55a');
      AES.DecryptBlock(Blk);
      Move(Blk[0], Out1[0], 16);
      Check('AES-128 decrypt', BytesToHex(Out1) = '00112233445566778899aabbccddeeff');

      // Hash helpers
      Check('SHA-1', BytesToHex(SHA1Of(Utf8('hunter2'))) = 'f3bbbd66a63d4bf1747940578ec3d0103530e21d');
      Check('MD5', BytesToHex(MD5Of(Utf8('admin'))) = '21232f297a57a5a743894a0e4a801fc3');

      // Field / point basics
      PG := ECMul(PointG, FN.M);   // n * G = infinity
      Check('P-256 n*G = O', PG.Inf);
      Check('P-256 M, N decode', not PointM.Inf and not PointN.Inf);

      // Wide reduction (tapo scalar_from_wide vectors)
      Check('mod n reduction (2^256)', BytesToHex(U256ToBE(FN.ReduceWide(HexToBytes('01' +
        StringOfChar('0', 64))))) = '00000000ffffffff00000000000000004319055258e8617b0c46353d039cdaaf');
      Check('mod n reduction (2^320-1)', BytesToHex(U256ToBE(FN.ReduceWide(HexToBytes(
        StringOfChar('f', 80))))) = 'fffffffe00000001431905529c0166cd22159165b6faae70f756a571fc632550');

      // PBKDF2 -> w0, w1 (tapo derive_w0_w1 vector)
      DeriveW0W1('f3bbbd66a63d4bf1747940578ec3d0103530e21d', Utf8('0123456789abcdef'), 3000, W0, W1);
      Check('PBKDF2 w0', BytesToHex(U256ToBE(W0)) = 'f01588c03f935783a7c530a83ab1ade1a3261b13005521b6946dc5c7ad259f2c');
      Check('PBKDF2 w1', BytesToHex(U256ToBE(W1)) = 'de9bd4a17ba3b23e2a26fbf5ae94010c68f5e0e34388fe6ec227fcb45bd0b42e');

      // SPAKE2+ (RFC 9383 test vector)
      Proof := SpakeProveWith(
        FN.ReduceWide(HexToBytes('bb8e1bbcf3c48f62c08db243652ae55d3e5586053fca77102994f23ad95491b3')),
        FN.ReduceWide(HexToBytes('7e945f34d78785b8a3ef44d0df5a1a97d6b3b460409a345ca7830387a74b1dba')),
        FN.ReduceWide(HexToBytes('d1232c8e8693d02368976c174e2088851b8365d0d79a9eee709c6a05a2fad539')),
        Utf8('SPAKE2+-P256-SHA256-HKDF-SHA256-HMAC-SHA256 Test Vectors'), Utf8('client'), Utf8('server'),
        HexToBytes('04c0f65da0d11927bdf5d560c69e1d7d939a05b0e88291887d679fcadea75810fb' +
                   '5cc1ca7494db39e82ff2f50665255d76173e09986ab46742c798a9a68437b048'));
      Check('SPAKE2+ share', BytesToHex(Proof.Share) =
        '04ef3bd051bf78a2234ec0df197f7828060fe9856503579bb1733009042c15c0c1' +
        'de127727f418b5966afadfdd95a6e4591d171056b333dab97a79c7193e341727');
      Check('SPAKE2+ confirm', BytesToHex(Proof.Confirm) =
        '926cc713504b9b4d76c9162ded04b5493e89109f6d89462cd33adc46fda27527');
      Check('SPAKE2+ shared key', BytesToHex(Proof.SharedKey) =
        '0c5f8ccd1413423a54f6c1fb26ff01534a87f893779c6e68666d772bfd91f3e7');
      Check('SPAKE2+ verifier confirm', BytesToHex(HMACSHA256(Proof.VerifierConfirmKey, Proof.Share)) =
        '9747bcc4f8fe9f63defee53ac9b07876d907d55047e6ff2def2e7529089d3e68');

      // TPAP session cipher (tapo tpap_cipher known answer)
      SetLength(SharedKey, 32);
      for I := 0 to 31 do
        SharedKey[I] := I;
      Key := HKDFSHA256(SharedKey, Utf8('tp-kdf-salt-aes128-key'), Utf8('tp-kdf-info-aes128-key'), 16);
      BaseNonce := HKDFSHA256(SharedKey, Utf8('tp-kdf-salt-aes128-iv'), Utf8('tp-kdf-info-aes128-iv'), 12);
      Nonce := Cat([Copy(BaseNonce, 0, 8), Int32BE($01020304)]);
      Body := Cat([Int32BE($01020304),
        AES128CCMEncrypt(Key, Nonce, Utf8('{"method":"get_device_info"}'))]);
      Check('AES-128-CCM encrypt', BytesToHex(Body) =
        '01020304c0331c1c36a5df4ce0c68e5a27b2667ebf842dc994a3fd24b9e860a60fab76d4' +
        'b66b9b669d95cca10c012f13');
      Check('AES-128-CCM decrypt', AES128CCMDecrypt(Key, Nonce, Copy(Body, 4, Length(Body) - 4), Plain) and
        (TEncoding.UTF8.GetString(Plain) = '{"method":"get_device_info"}'));
      Body[10] := Body[10] xor 1;
      Check('AES-128-CCM rejects tampering', not AES128CCMDecrypt(Key, Nonce,
        Copy(Body, 4, Length(Body) - 4), Plain));
    except
      on E: Exception do
      begin
        Lines.Add('EXCEPTION ' + E.ClassName + ': ' + E.Message);
        AllOK := False;
      end;
    end;
    AReport := Lines.Text;
    Result := AllOK;
  finally
    Lines.Free;
  end;
end;


initialization
  InitAESTables;
  InitP256;
  Randomize;

end.
