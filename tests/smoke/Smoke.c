// Smoke test for a packaged Dawn: built against an unpacked archive with no Dawn sources present.
//
// It creates an instance, an adapter and a device through webgpu.h's C API, compiles a compute
// pipeline (which runs the shader compiler), and checks the adapter is on the backend this platform
// is meant to use. On Windows it also checks that Dawn used DXC, the dxcompiler.dll shipped beside
// the library, rather than falling back to FXC. Prints SMOKE_PASS and exits 0 when everything works.

#include <webgpu/webgpu.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#define SMOKE_EXPECTED_BACKEND WGPUBackendType_D3D12
#elif defined(__APPLE__)
#define SMOKE_EXPECTED_BACKEND WGPUBackendType_Metal
#else
#define SMOKE_EXPECTED_BACKEND WGPUBackendType_Vulkan
#endif

typedef struct SmokeState
{
	int Done;
	WGPUAdapter Adapter;
	WGPUDevice Device;
	int ErrorCount;
	char Message[1024];
} SmokeState;

static void CopyMessage(SmokeState* State, WGPUStringView Message)
{
	size_t Length = Message.length == WGPU_STRLEN ? (Message.data ? strlen(Message.data) : 0) : Message.length;
	if (Length >= sizeof(State->Message))
	{
		Length = sizeof(State->Message) - 1;
	}
	if (Length > 0)
	{
		memcpy(State->Message, Message.data, Length);
	}
	State->Message[Length] = '\0';
}

static void PrintView(const char* Label, WGPUStringView View)
{
	const int Length = View.length == WGPU_STRLEN ? (int)(View.data ? strlen(View.data) : 0) : (int)View.length;
	printf("%s: %.*s\n", Label, Length, View.data ? View.data : "");
}

static const char* BackendName(WGPUBackendType Backend)
{
	switch (Backend)
	{
	case WGPUBackendType_Null: return "Null";
	case WGPUBackendType_WebGPU: return "WebGPU";
	case WGPUBackendType_D3D11: return "D3D11";
	case WGPUBackendType_D3D12: return "D3D12";
	case WGPUBackendType_Metal: return "Metal";
	case WGPUBackendType_Vulkan: return "Vulkan";
	case WGPUBackendType_OpenGL: return "OpenGL";
	case WGPUBackendType_OpenGLES: return "OpenGLES";
	default: return "Unknown";
	}
}

static void OnAdapter(WGPURequestAdapterStatus Status, WGPUAdapter Adapter, WGPUStringView Message, void* Userdata1,
	void* Userdata2)
{
	(void)Userdata2;
	SmokeState* State = (SmokeState*)Userdata1;
	if (Status == WGPURequestAdapterStatus_Success)
	{
		State->Adapter = Adapter;
	}
	else
	{
		CopyMessage(State, Message);
	}
	State->Done = 1;
}

static void OnDevice(WGPURequestDeviceStatus Status, WGPUDevice Device, WGPUStringView Message, void* Userdata1,
	void* Userdata2)
{
	(void)Userdata2;
	SmokeState* State = (SmokeState*)Userdata1;
	if (Status == WGPURequestDeviceStatus_Success)
	{
		State->Device = Device;
	}
	else
	{
		CopyMessage(State, Message);
	}
	State->Done = 1;
}

static void OnUncapturedError(const WGPUDevice* Device, WGPUErrorType Type, WGPUStringView Message, void* Userdata1,
	void* Userdata2)
{
	(void)Device;
	(void)Type;
	(void)Userdata2;
	SmokeState* State = (SmokeState*)Userdata1;
	++State->ErrorCount;
	PrintView("uncaptured error", Message);
}

static void OnPopErrorScope(WGPUPopErrorScopeStatus Status, WGPUErrorType Type, WGPUStringView Message,
	void* Userdata1, void* Userdata2)
{
	(void)Userdata2;
	SmokeState* State = (SmokeState*)Userdata1;
	if (Status != WGPUPopErrorScopeStatus_Success || Type != WGPUErrorType_NoError)
	{
		++State->ErrorCount;
		PrintView("pipeline error", Message);
	}
	State->Done = 1;
}

static void Wait(WGPUInstance Instance, SmokeState* State)
{
	while (!State->Done)
	{
		wgpuInstanceProcessEvents(Instance);
	}
	State->Done = 0;
}

static int Fail(const char* What, const SmokeState* State)
{
	printf("SMOKE_FAIL: %s%s%s\n", What, State->Message[0] ? ": " : "", State->Message);
	return 1;
}

static WGPUAdapter RequestAdapter(WGPUInstance Instance, SmokeState* State, WGPUBool Fallback)
{
	WGPURequestAdapterOptions Options = WGPU_REQUEST_ADAPTER_OPTIONS_INIT;
	Options.backendType = SMOKE_EXPECTED_BACKEND;
	Options.forceFallbackAdapter = Fallback;
	WGPURequestAdapterCallbackInfo Callback = WGPU_REQUEST_ADAPTER_CALLBACK_INFO_INIT;
	Callback.mode = WGPUCallbackMode_AllowProcessEvents;
	Callback.callback = OnAdapter;
	Callback.userdata1 = State;
	State->Adapter = NULL;
	State->Message[0] = '\0';
	wgpuInstanceRequestAdapter(Instance, &Options, Callback);
	Wait(Instance, State);
	return State->Adapter;
}

int main(void)
{
	SmokeState State;
	memset(&State, 0, sizeof(State));

	const WGPUInstance Instance = wgpuCreateInstance(NULL);
	if (!Instance)
	{
		return Fail("wgpuCreateInstance returned null", &State);
	}

	// CI machines have no GPU: Windows has WARP and Linux has lavapipe, which Dawn reports as
	// fallback (CPU) adapters, used only when no hardware adapter is found.
	WGPUAdapter Adapter = RequestAdapter(Instance, &State, 0);
	if (!Adapter)
	{
		printf("no hardware adapter (%s); trying the fallback adapter\n", State.Message);
		Adapter = RequestAdapter(Instance, &State, 1);
	}
	if (!Adapter)
	{
		return Fail("no adapter", &State);
	}

	WGPUAdapterInfo Info = WGPU_ADAPTER_INFO_INIT;
	if (wgpuAdapterGetInfo(Adapter, &Info) != WGPUStatus_Success)
	{
		return Fail("wgpuAdapterGetInfo failed", &State);
	}
	printf("backend: %s\n", BackendName(Info.backendType));
	PrintView("vendor", Info.vendor);
	PrintView("device", Info.device);
	PrintView("description", Info.description);
	const WGPUBackendType Backend = Info.backendType;
	wgpuAdapterInfoFreeMembers(Info);
	if (Backend != SMOKE_EXPECTED_BACKEND)
	{
		return Fail("the adapter is not on the backend this platform should use", &State);
	}

	WGPUDeviceDescriptor DeviceDescriptor = WGPU_DEVICE_DESCRIPTOR_INIT;
	DeviceDescriptor.uncapturedErrorCallbackInfo.callback = OnUncapturedError;
	DeviceDescriptor.uncapturedErrorCallbackInfo.userdata1 = &State;
	WGPURequestDeviceCallbackInfo DeviceCallback = WGPU_REQUEST_DEVICE_CALLBACK_INFO_INIT;
	DeviceCallback.mode = WGPUCallbackMode_AllowProcessEvents;
	DeviceCallback.callback = OnDevice;
	DeviceCallback.userdata1 = &State;
	wgpuAdapterRequestDevice(Adapter, &DeviceDescriptor, DeviceCallback);
	Wait(Instance, &State);
	const WGPUDevice Device = State.Device;
	if (!Device)
	{
		return Fail("no device", &State);
	}

	// A compute pipeline makes Dawn translate the WGSL and compile it with the backend's compiler.
	WGPUShaderSourceWGSL Source = WGPU_SHADER_SOURCE_WGSL_INIT;
	const char* Code = "@group(0) @binding(0) var<storage, read_write> Values : array<u32>;\n"
					   "@compute @workgroup_size(64) fn main(@builtin(global_invocation_id) Id : vec3u) {\n"
					   "  Values[Id.x] = Values[Id.x] * 2u + 1u;\n"
					   "}\n";
	Source.code.data = Code;
	Source.code.length = WGPU_STRLEN;
	WGPUShaderModuleDescriptor ModuleDescriptor = WGPU_SHADER_MODULE_DESCRIPTOR_INIT;
	ModuleDescriptor.nextInChain = &Source.chain;

	wgpuDevicePushErrorScope(Device, WGPUErrorFilter_Validation);
	const WGPUShaderModule Module = wgpuDeviceCreateShaderModule(Device, &ModuleDescriptor);
	WGPUComputePipelineDescriptor PipelineDescriptor = WGPU_COMPUTE_PIPELINE_DESCRIPTOR_INIT;
	PipelineDescriptor.compute.module = Module;
	const WGPUComputePipeline Pipeline = wgpuDeviceCreateComputePipeline(Device, &PipelineDescriptor);
	WGPUPopErrorScopeCallbackInfo ScopeCallback = WGPU_POP_ERROR_SCOPE_CALLBACK_INFO_INIT;
	ScopeCallback.mode = WGPUCallbackMode_AllowProcessEvents;
	ScopeCallback.callback = OnPopErrorScope;
	ScopeCallback.userdata1 = &State;
	wgpuDevicePopErrorScope(Device, ScopeCallback);
	Wait(Instance, &State);
	if (!Pipeline || State.ErrorCount > 0)
	{
		return Fail("creating a compute pipeline failed", &State);
	}

#if defined(_WIN32)
	// Dawn loads DXC when it compiles the first shader with it.
	if (!GetModuleHandleA("dxcompiler.dll"))
	{
		return Fail("Dawn did not load dxcompiler.dll, so it compiled with FXC instead of DXC", &State);
	}
	printf("shader compiler: DXC\n");
#endif

	wgpuComputePipelineRelease(Pipeline);
	wgpuShaderModuleRelease(Module);
	wgpuDeviceRelease(Device);
	wgpuAdapterRelease(Adapter);
	wgpuInstanceRelease(Instance);

	printf("SMOKE_PASS\n");
	return 0;
}
