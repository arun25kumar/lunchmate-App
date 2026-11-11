/// Payment settings for the "Pay Now" button.
///
/// Leave both empty so the app uses the UPI ID and admin name saved on the
/// team (entered when the team is created).
/// Fill kUpiId only if you want to force one UPI ID for every team.
const String kUpiId = '';

/// Name shown in the UPI app as the person being paid.
/// Leave empty ('') to use the admin's name from the team.
const String kPayeeName = '';