part of 'controllers.dart';

class DefaultAuthController extends Cubit<Response<AuthInfo>> {
  final AuthHandler handler;
  final DataHandler<AuthInfo> userHandler;
  final String Function(String uid)? createUid;

  DefaultAuthController({
    required this.handler,
    required this.userHandler,
    this.createUid,
  }) : super(Response<AuthInfo>());

  String get uid => user?.uid ?? "uid";

  User? get user => FirebaseAuth.instance.currentUser;

  Future<bool> get isLoggedIn async {
    try {
      emit(state.copy(loading: true));
      final signedIn = await handler.isSignIn();
      if (signedIn) {
        emit(state.copy(successful: true));
      } else {
        emit(state.copy(exception: "User logged out!"));
      }
      return signedIn;
    } catch (e) {
      emit(state.copy(exception: e.toString()));
      return Future.error(e);
    }
  }

  Future<Response> signUpByEmail(AuthInfo entity) async {
    final cubitResponse = Response();
    final email = entity.email;
    final password = entity.password;
    if (!Validator.isValidEmail(email)) {
      emit(state.copy(exception: "Email isn't valid!"));
      return cubitResponse.copy(message: "Email isn't valid!");
    } else if (!Validator.isValidPassword(password)) {
      emit(state.copy(exception: "Password isn't valid!"));
      return cubitResponse.copy(message: "Password isn't valid!");
    } else {
      try {
        emit(state.copy(loading: true));
        final response = await handler.signUpWithEmailNPassword(
          email: email,
          password: password,
        );
        final result = response.data?.user;
        if (result != null) {
          final user = entity.copy(
            id: createUid?.call(result.uid) ?? result.uid,
            email: result.email,
            phone: result.phoneNumber,
            name: result.displayName,
            photo: result.photoURL,
          );
          final userResponse = await userHandler.insert(
            user,
            cacheMode: true,
          );
          if (userResponse.isSuccessful || userResponse.snapshot != null) {
            emit(state.copy(data: user));
          } else {
            emit(state.copy(exception: userResponse.message));
          }
          return userResponse.copy(data: user);
        } else {
          emit(state.copy(exception: response.message));
          return response;
        }
      } catch (e) {
        emit(state.copy(exception: e.toString()));
        return cubitResponse.copy(message: e.toString());
      }
    }
  }

  void signInByEmail(AuthInfo entity) async {
    final email = entity.email;
    final password = entity.password;
    if (!Validator.isValidEmail(email)) {
      emit(state.copy(
        exception: "Email isn't valid!",
        status: Status.invalid,
      ));
    } else if (!Validator.isValidPassword(password)) {
      emit(state.copy(
        exception: "Password isn't valid!",
        status: Status.invalid,
      ));
    } else {
      try {
        emit(state.copy(loading: true));
        final response = await handler.signInWithEmailNPassword(
          email: email,
          password: password,
        );
        if (response.isSuccessful) {
          final result = response.data?.user;
          if (result != null) {
            final user = entity.copy(
              id: createUid?.call(result.uid) ?? result.uid,
              email: result.email,
              name: result.displayName,
              phone: result.phoneNumber,
              photo: result.photoURL,
              provider: AuthProvider.email.name,
            );
            await userHandler.insert(
              user,
              localMode: true,
            );
            emit(state.copy(data: user));
          }
        }
        emit(state.copy(exception: response.exception));
      } catch (e) {
        emit(state.copy(exception: e.toString()));
      }
    }
  }

  Future<Response> signInByFacebook(AuthInfo entity) async {
    emit(state.copy(loading: true));
    final response = await handler.signInWithFacebook();
    final result = response.data;
    if (result != null && result.credential != null) {
      final finalResponse = await handler.signUpWithCredential(
        credential: result.credential!,
      );
      if (finalResponse.isSuccessful) {
        final currentData = finalResponse.data?.user;
        final user = entity.copy(
          id: createUid?.call(currentData?.uid ?? result.id ?? uid) ??
              currentData?.uid ??
              result.id,
          email: result.email,
          name: result.name,
          photo: result.photo,
          provider: AuthProvider.facebook.name,
        );
        final userResponse = await userHandler.insert(
          user,
          cacheMode: true,
        );
        if (userResponse.isSuccessful || userResponse.snapshot != null) {
          emit(state.copy(data: user));
        } else {
          emit(state.copy(exception: userResponse.message));
        }
        return userResponse.copy(data: user);
      } else {
        emit(state.copy(exception: finalResponse.message));
        return finalResponse;
      }
    } else {
      emit(state.copy(exception: response.message));
      return response;
    }
  }

  Future<Response> signInByGoogle(AuthInfo entity) async {
    emit(state.copy(loading: true));
    final response = await handler.signInWithGoogle();
    final result = response.data;
    if (result != null && result.credential != null) {
      final finalResponse = await handler.signUpWithCredential(
        credential: result.credential!,
      );
      if (finalResponse.isSuccessful) {
        final currentData = finalResponse.data?.user;
        final user = entity.copy(
          id: createUid?.call(currentData?.uid ?? result.id ?? uid) ??
              currentData?.uid ??
              result.id,
          name: result.name,
          photo: result.photo,
          email: result.email,
          provider: AuthProvider.google.name,
        );
        final userResponse = await userHandler.insert(
          user,
          cacheMode: true,
        );
        if (userResponse.isSuccessful || userResponse.snapshot != null) {
          emit(state.copy(data: user));
        } else {
          emit(state.copy(exception: userResponse.message));
        }
        return userResponse.copy(data: user);
      } else {
        emit(state.copy(exception: finalResponse.message));
        return finalResponse;
      }
    } else {
      emit(state.copy(exception: response.message));
      return response;
    }
  }

  Future<Response> signInByBiometric() async {
    emit(state.copy(loading: true));
    final response = await handler.signInWithBiometric();
    if (response.isSuccessful) {
      final userResponse = await userHandler.get(
        createUid?.call(uid) ?? uid,
        localMode: true,
      );
      final user = userResponse.data;
      if (userResponse.isSuccessful && user is AuthInfo) {
        final email = user.email;
        final password = user.password;
        final loginResponse = await handler.signInWithEmailNPassword(
          email: email,
          password: password,
        );
        if (loginResponse.isSuccessful) {
          emit(state.copy(data: user));
        } else {
          emit(state.copy(exception: loginResponse.message));
        }
        return loginResponse;
      } else {
        emit(state.copy(exception: userResponse.message));
      }
      return userResponse;
    } else {
      emit(state.copy(exception: response.message));
    }
    return response;
  }

  Future<Response> signOut() async {
    emit(state.copy(loading: true));
    final response = await handler.signOut();
    if (response.isSuccessful) {
      final userResponse =
          await userHandler.delete(createUid?.call(uid) ?? uid);
      if (userResponse.isSuccessful || userResponse.snapshot != null) {
        emit(state.copy(data: null));
      } else {
        emit(state.copy(exception: userResponse.message));
      }
      return userResponse.copy(data: null);
    } else {
      emit(state.copy(exception: response.message));
      return response;
    }
  }
}
