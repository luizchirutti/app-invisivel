import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/protection_usecases.dart';
import '../../core/errors/failures.dart';

/// Estados do Protection BLoC
abstract class ProtectionState extends Equatable {
  const ProtectionState();

  @override
  List<Object?> get props => [];
}

class ProtectionInitial extends ProtectionState {
  const ProtectionInitial();
}

class ProtectionLoading extends ProtectionState {
  const ProtectionLoading();
}

class ProtectionActive extends ProtectionState {
  final ProtectionStatus status;

  const ProtectionActive(this.status);

  @override
  List<Object?> get props => [status];
}

class ProtectionInactive extends ProtectionState {
  const ProtectionInactive();
}

class ProtectionError extends ProtectionState {
  final String message;

  const ProtectionError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Eventos do Protection BLoC
abstract class ProtectionEvent extends Equatable {
  const ProtectionEvent();

  @override
  List<Object?> get props => [];
}

class StartProtectionEvent extends ProtectionEvent {
  final AppConfiguration config;

  const StartProtectionEvent(this.config);

  @override
  List<Object?> get props => [config];
}

class StopProtectionEvent extends ProtectionEvent {
  const StopProtectionEvent();
}

class GetStatusEvent extends ProtectionEvent {
  const GetStatusEvent();
}

class UpdateStatusEvent extends ProtectionEvent {
  final ProtectionStatus status;

  const UpdateStatusEvent(this.status);

  @override
  List<Object?> get props => [status];
}

/// BLoC de Proteção
class ProtectionBloc extends Bloc<ProtectionEvent, ProtectionState> {
  final StartProtectionUseCase startProtectionUseCase;
  final StopProtectionUseCase stopProtectionUseCase;
  final GetProtectionStatusUseCase getProtectionStatusUseCase;

  ProtectionBloc({
    required this.startProtectionUseCase,
    required this.stopProtectionUseCase,
    required this.getProtectionStatusUseCase,
  }) : super(const ProtectionInitial()) {
    on<StartProtectionEvent>(_onStartProtection);
    on<StopProtectionEvent>(_onStopProtection);
    on<GetStatusEvent>(_onGetStatus);
    on<UpdateStatusEvent>(_onUpdateStatus);
  }

  Future<void> _onStartProtection(
    StartProtectionEvent event,
    Emitter<ProtectionState> emit,
  ) async {
    emit(const ProtectionLoading());

    final result = await startProtectionUseCase(event.config);

    result.fold(
      (failure) => emit(ProtectionError(failure.message)),
      (status) => emit(ProtectionActive(status)),
    );
  }

  Future<void> _onStopProtection(
    StopProtectionEvent event,
    Emitter<ProtectionState> emit,
  ) async {
    emit(const ProtectionLoading());

    final result = await stopProtectionUseCase();

    result.fold(
      (failure) => emit(ProtectionError(failure.message)),
      (_) => emit(const ProtectionInactive()),
    );
  }

  Future<void> _onGetStatus(
    GetStatusEvent event,
    Emitter<ProtectionState> emit,
  ) async {
    final result = await getProtectionStatusUseCase();

    result.fold(
      (failure) => emit(ProtectionError(failure.message)),
      (status) {
        if (status.isVPNActive) {
          emit(ProtectionActive(status));
        } else {
          emit(const ProtectionInactive());
        }
      },
    );
  }

  Future<void> _onUpdateStatus(
    UpdateStatusEvent event,
    Emitter<ProtectionState> emit,
  ) async {
    if (event.status.isVPNActive) {
      emit(ProtectionActive(event.status));
    } else {
      emit(const ProtectionInactive());
    }
  }
}
