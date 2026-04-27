// developer.apple.com/documentation/eventkit/ekstructuredlocation

export interface GeoLocation {
    latitude: number;
    longitude: number;
}

export class EKStructuredLocation {
    title: string | null;
    geoLocation: GeoLocation | null;
    radius: number;  // meters; 0 = "use default"
}
