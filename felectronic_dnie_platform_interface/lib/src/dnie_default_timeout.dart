/// How long DNIe operations wait for a card unless told otherwise.
///
/// Android clamps any timeout to between 3 and 30 seconds. iOS does not use
/// it: Core NFC ends every reader session after 60 seconds on its own.
const dnieDefaultTimeout = Duration(seconds: 30);
