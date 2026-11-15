enum RepositoryReadStatus { unavailable, loading, ready, error }

/// Métadonnées de lecture uniquement ; aucune valeur statistique de secours.
class RepositoryReadState {
  const RepositoryReadState.unavailable()
    : status = RepositoryReadStatus.unavailable,
      error = null;
  const RepositoryReadState.loading()
    : status = RepositoryReadStatus.loading,
      error = null;
  const RepositoryReadState.ready()
    : status = RepositoryReadStatus.ready,
      error = null;
  const RepositoryReadState.error(this.error)
    : status = RepositoryReadStatus.error;

  final RepositoryReadStatus status;
  final Object? error;
}
