export interface IAdaptable {
    // would ideally make these methods static
    fromSwiftModel(object: any): any
    toSwiftModel(): any
}
