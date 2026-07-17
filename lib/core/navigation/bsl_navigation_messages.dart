import 'package:google_navigation_flutter/google_navigation_flutter.dart';

abstract final class BslNavigationMessages {
  static String forRouteStatus(NavigationRouteStatus status) {
    switch (status) {
      case NavigationRouteStatus.statusOk:
        return '';
      case NavigationRouteStatus.routeNotFound:
        return 'Nije pronađena vozna ruta do odabranog odredišta.';
      case NavigationRouteStatus.networkError:
        return 'Za izračun rute potrebna je stabilna internet veza.';
      case NavigationRouteStatus.quotaExceeded:
        return 'Kvota za navigaciju je potrošena.';
      case NavigationRouteStatus.quotaCheckFailed:
        return 'Google trenutno ne može provjeriti kvotu za navigaciju.';
      case NavigationRouteStatus.apiKeyNotAuthorized:
        return 'Google ključ nije autorizovan za Navigation SDK.';
      case NavigationRouteStatus.locationUnavailable:
      case NavigationRouteStatus.locationUnknown:
        return 'Još nema dovoljno preciznog GPS signala za sigurnu rutu.';
      case NavigationRouteStatus.waypointError:
        return 'Koordinate odabranog odredišta nisu ispravne.';
      case NavigationRouteStatus.travelModeUnsupported:
        return 'Vožnja automobilom nije podržana za ovu rutu.';
      case NavigationRouteStatus.statusCanceled:
        return 'Izračun rute je prekinut novim zahtjevom.';
      case NavigationRouteStatus.duplicateWaypointsError:
      case NavigationRouteStatus.noWaypointsError:
        return 'Odredište za navigaciju nije ispravno postavljeno.';
      case NavigationRouteStatus.internalError:
      case NavigationRouteStatus.unknown:
        return 'Navigacija trenutno ne može izračunati rutu.';
    }
  }

  static String forInitializationError(SessionInitializationError error) {
    switch (error) {
      case SessionInitializationError.notAuthorized:
        return 'Navigation SDK nije omogućen za lokalni Google Maps ključ.';
      case SessionInitializationError.locationPermissionMissing:
        return 'Za navigaciju je potrebna dozvola za preciznu lokaciju.';
      case SessionInitializationError.termsNotAccepted:
        return 'Za korištenje navigacije potrebno je prihvatiti uslove.';
    }
  }
}
