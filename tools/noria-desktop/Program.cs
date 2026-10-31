using System.Diagnostics;
using System.IO.Compression;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Xml.Linq;
using System.Net.Sockets;

namespace NoriaDesktop;

static class Program
{
    [STAThread] static int Main(string[] args)
    {
        if (args.Contains("--self-test")) return Engine.SelfTest();
        if (args.Contains("--adb-self-test")) return Engine.AdbSelfTest();
        ApplicationConfiguration.Initialize();
        Application.Run(new MainWindow());
        return 0;
    }
}

sealed class MainWindow : Form
{
    readonly Color navy = ColorTranslator.FromHtml("#05213d"), cyan = ColorTranslator.FromHtml("#28f2ff");
    readonly TextBox log = new() { Multiline=true, ReadOnly=true, ScrollBars=ScrollBars.Vertical, Dock=DockStyle.Fill, BackColor=Color.FromArgb(2,11,27), ForeColor=Color.FromArgb(166,196,213), BorderStyle=BorderStyle.None, Font=new Font("Consolas",10) };
    readonly Label status = new() { Text="Spremno • priprema Androida pri prvom korišćenju", AutoSize=true, ForeColor=Color.White, Margin=new Padding(0,15,0,15) };
    readonly ComboBox graphics = new() { DropDownStyle=ComboBoxStyle.DropDownList, Width=210 };
    readonly List<Button> buttons = new();
    readonly Engine engine;
    bool busy;
    public MainWindow()
    {
        Text="Noria Desktop 0.1.2 • Android radni prostor"; Size=new Size(1160,800); MinimumSize=new Size(980,700); StartPosition=FormStartPosition.CenterScreen;
        BackColor=navy; ForeColor=Color.White; Font=new Font("Segoe UI",10); AutoScaleMode=AutoScaleMode.Dpi;
        engine=new Engine(WriteLog);
        try { Icon=System.Drawing.Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }
        var shell=new TableLayoutPanel { Dock=DockStyle.Fill, ColumnCount=2, RowCount=1, Padding=new Padding(20) };
        shell.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,245)); shell.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100)); Controls.Add(shell);
        var side=new FlowLayoutPanel { Dock=DockStyle.Fill, FlowDirection=FlowDirection.TopDown, WrapContents=false, Padding=new Padding(8), AutoScroll=true };
        shell.Controls.Add(side,0,0);
        var logo=new PictureBox { Size=new Size(205,180), SizeMode=PictureBoxSizeMode.Zoom };
        using(var s=typeof(Program).Assembly.GetManifestResourceStream("NoriaDesktop.noria-logo.png")) if(s!=null) { using var original=new Bitmap(s); logo.Image=new Bitmap(original); }
        side.Controls.Add(logo);
        side.Controls.Add(new Label { Text="NORIA DESKTOP", Font=new Font("Segoe UI",17,FontStyle.Bold), ForeColor=cyan, AutoSize=true, Margin=new Padding(0,10,0,15) });
        Add(side,"1. Pripremi Android",()=>engine.SetupAsync());
        Add(side,"2. Pokreni Android",()=>engine.StartAsync(graphics.SelectedIndex==1));
        Add(side,"3. Instaliraj BSL i NRN",()=>engine.InstallBundledAsync());
        Add(side,"Otvori BSL",()=>engine.LaunchAsync("ba.balkansmartlife.app"));
        Add(side,"Otvori NRN",()=>engine.LaunchAsync("com.example.mesh_messenger_test.nrnpilot"));
        Add(side,"Instaliraj drugi APK",InstallOther);
        Add(side,"Zaustavi Android",()=>engine.StopAsync());
        var main=new TableLayoutPanel { Dock=DockStyle.Fill, ColumnCount=1, RowCount=7, Padding=new Padding(20,8,0,0) };
        main.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
        main.RowStyles.Add(new RowStyle(SizeType.Absolute,50)); main.RowStyles.Add(new RowStyle(SizeType.Absolute,78));
        main.RowStyles.Add(new RowStyle(SizeType.Absolute,50)); main.RowStyles.Add(new RowStyle(SizeType.Absolute,48));
        main.RowStyles.Add(new RowStyle(SizeType.Absolute,62)); main.RowStyles.Add(new RowStyle(SizeType.Percent,100)); main.RowStyles.Add(new RowStyle(SizeType.Absolute,42));
        shell.Controls.Add(main,1,0);
        main.Controls.Add(new Label { Text="Tvoj Android. Na velikom ekranu.", Font=new Font("Segoe UI",21,FontStyle.Bold), Dock=DockStyle.Fill, ForeColor=cyan },0,0);
        main.Controls.Add(new Label { Text="BSL i NRN rade na računaru, bez telefona. Android se otvara u zasebnom prozoru i koristi miš i tastaturu. Prvo preuzimanje je nekoliko GB; rezerviši najmanje 18 GB slobodnog prostora.", Dock=DockStyle.Fill },0,1);
        main.Controls.Add(status,0,2);
        var options=new FlowLayoutPanel { Dock=DockStyle.Fill };
        options.Controls.Add(new Label { Text="Grafički prikaz:", AutoSize=true, Padding=new Padding(0,6,8,0) });
        graphics.Items.AddRange(new object[]{"Automatski / GPU", "Softverski (ako je crn ekran)"}); graphics.SelectedIndex=0; options.Controls.Add(graphics); main.Controls.Add(options,0,3);
        var actions=new FlowLayoutPanel { Dock=DockStyle.Fill };
        Add(actions,"Provjeri sistem",()=>engine.DiagnosticsAsync(),170);
        Add(actions,"Windows funkcije",()=>{ Process.Start(new ProcessStartInfo("optionalfeatures.exe"){UseShellExecute=true}); return Task.CompletedTask; },170);
        Add(actions,"Otvori podatke",()=>{ Process.Start(new ProcessStartInfo("explorer.exe",engine.Root){UseShellExecute=true}); return Task.CompletedTask; },150);
        Add(actions,"Kopiraj dnevnik",()=>{ Clipboard.SetText(log.Text.Length>0?log.Text:"Dnevnik je prazan."); return Task.CompletedTask; },145);
        main.Controls.Add(actions,0,4); main.Controls.Add(log,0,5);
        main.Controls.Add(new Label { Text="Android 15 • 1920 × 1080 • 4 GB RAM • 2 CPU | NRN radio-veze zahtijevaju zasebno testiranje", Dock=DockStyle.Fill, ForeColor=Color.FromArgb(166,196,213), Padding=new Padding(0,10,0,0) },0,6);
        WriteLog("Dobro došao. Redom odaberi pripremu, pokretanje i instalaciju aplikacija.");
        WriteLog("Ako ubrzanje nije dostupno: Windows funkcije → Windows Hypervisor Platform → restart računara.");
        WriteLog("Verzija 0.1.2 • detaljni dnevnik: "+Path.Combine(engine.Root,"noria-desktop.log"));
        FormClosed+=(_,_)=>engine.ReleaseServer();
    }
    void Add(Control parent,string title,Func<Task> action,int width=215)
    {
        var b=new Button { Text=title, Size=new Size(width,42), Margin=new Padding(0,0,8,9), BackColor=Color.FromArgb(7,51,85), ForeColor=Color.White, FlatStyle=FlatStyle.Flat, Cursor=Cursors.Hand };
        b.FlatAppearance.BorderColor=cyan; buttons.Add(b); parent.Controls.Add(b);
        b.Paint+=(_,e)=>{ if(!b.Enabled) { e.Graphics.Clear(b.BackColor); ControlPaint.DrawBorder(e.Graphics,b.ClientRectangle,cyan,ButtonBorderStyle.Solid); TextRenderer.DrawText(e.Graphics,b.Text,b.Font,b.ClientRectangle,Color.FromArgb(166,196,213),TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter); } };
        b.Click+=async(_,_)=>{ if(busy)return; busy=true; buttons.ForEach(x=>x.Enabled=false); status.Text=title+"…";
            try { await action(); status.Text="Završeno • "+title; }
            catch(Exception ex) { status.Text="Operacija nije završena"; WriteLog("GREŠKA: "+ex.Message); MessageBox.Show(this,ex.Message,"Noria Desktop",MessageBoxButtons.OK,MessageBoxIcon.Warning); }
            finally { busy=false; buttons.ForEach(x=>x.Enabled=true); }
        };
    }
    Task InstallOther()
    {
        using var d=new OpenFileDialog { Filter="Android aplikacija (*.apk)|*.apk", Title="Odaberi APK" };
        return d.ShowDialog(this)==DialogResult.OK ? engine.InstallAsync(d.FileName) : Task.CompletedTask;
    }
    void WriteLog(string line)
    {
        if(IsDisposed)return;
        if(InvokeRequired) { BeginInvoke(()=>WriteLog(line)); return; }
        log.AppendText($"[{DateTime.Now:HH:mm:ss}] {line}{Environment.NewLine}");
    }
}

sealed class Engine
{
    public readonly string Root=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"NoriaDesktop");
    readonly Action<string> log;
    string Sdk=>Path.Combine(Root,"sdk");
    string Avds=>Path.Combine(Root,"avd");
    string Adb=>Path.Combine(Sdk,"platform-tools","adb.exe");
    string Emulator=>Path.Combine(Sdk,"emulator","emulator.exe");
    string Java=>Path.Combine(AppContext.BaseDirectory,"runtime","java");
    string Manager=>Path.Combine(Sdk,"cmdline-tools","latest","bin","sdkmanager.bat");
    const int AdbPort=5039;
    Process? adbServer;
    readonly CancellationTokenSource lifetime=new();
    const string Image="system-images;android-35;google_apis;x86_64", Serial="emulator-5580", Avd="NoriaDesktop";
    public Engine(Action<string> logger)
    {
        Directory.CreateDirectory(Root); var sync=new object();
        log=line=>{ lock(sync) { try { File.AppendAllText(Path.Combine(Root,"noria-desktop.log"),$"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {line}{Environment.NewLine}"); } catch { } } logger(line); };
    }
    void EnvironmentFor(ProcessStartInfo p)
    {
        p.Environment["ANDROID_HOME"]=Sdk; p.Environment["ANDROID_SDK_ROOT"]=Sdk;
        p.Environment["ANDROID_AVD_HOME"]=Avds; p.Environment["ANDROID_USER_HOME"]=Path.Combine(Root,"android-user");
        p.Environment["JAVA_HOME"]=Java; p.Environment["PATH"]=Path.Combine(Java,"bin")+Path.PathSeparator+Environment.GetEnvironmentVariable("PATH");
        // Keep Noria separate from a stalled/default Android Studio/phone server.
        p.Environment.Remove("ADB_SERVER_SOCKET");
        p.Environment["ANDROID_ADB_SERVER_PORT"]=AdbPort.ToString();
        p.Environment["ADB_LIBUSB"]="0";
        p.Environment["ADB_MDNS_AUTO_CONNECT"]="";
    }
    static string Quote(string value)
    {
        if(value.IndexOfAny(new[]{'"','\r','\n','%'})>=0) throw new InvalidOperationException("Putanja sadrži nepodržane znakove.");
        return "\""+value+"\"";
    }
    ProcessStartInfo Info(string file,IEnumerable<string> args,bool visible=false)
    {
        var p=new ProcessStartInfo { FileName=file, UseShellExecute=false, CreateNoWindow=!visible, WorkingDirectory=Root };
        if(file.EndsWith(".bat",StringComparison.OrdinalIgnoreCase))
        {
            p.FileName=Environment.GetEnvironmentVariable("COMSPEC")??"cmd.exe";
            p.Arguments="/d /s /c \""+Quote(file)+" "+string.Join(" ",args.Select(Quote))+"\"";
        }
        else
        {
            var values=args.ToArray();
            if(Path.GetFileName(file).Equals("adb.exe",StringComparison.OrdinalIgnoreCase)&&!values.Contains("-L"))
            { p.ArgumentList.Add("-P"); p.ArgumentList.Add(AdbPort.ToString()); }
            foreach(var a in values)p.ArgumentList.Add(a);
        }
        EnvironmentFor(p); return p;
    }
    async Task<(int Code,string Text)> Run(string file,IEnumerable<string> args,string? input=null,int seconds=1800,bool quiet=false)
    {
        var arguments=args.ToArray();
        if(Path.GetFileName(file).Equals("adb.exe",StringComparison.OrdinalIgnoreCase)&&seconds==1800) seconds=arguments.Contains("install")?300:20;
        var label=Path.GetFileName(file)+" "+string.Join(" ",arguments);
        if(!quiet)log("Pokrećem: "+label);
        var p=Info(file,arguments); p.RedirectStandardOutput=true; p.RedirectStandardError=true; p.RedirectStandardInput=true;
        using var process=new Process { StartInfo=p }; var text=new StringBuilder(); var sync=new object();
        var stdoutDone=new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var stderrDone=new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        void Line(DataReceivedEventArgs e,TaskCompletionSource done) { if(e.Data==null) { done.TrySetResult(); return; } lock(sync)text.AppendLine(e.Data); if(!quiet)log(e.Data); }
        process.OutputDataReceived+=(_,e)=>Line(e,stdoutDone); process.ErrorDataReceived+=(_,e)=>Line(e,stderrDone);
        process.Start(); process.BeginOutputReadLine(); process.BeginErrorReadLine();
        if(input!=null)await process.StandardInput.WriteAsync(input); process.StandardInput.Close();
        // Wait for the command, not EOF on pipes inherited by a background server.
        // WaitForExitAsync and parameterless WaitForExit can wait for that server too.
        bool exited=await Task.Run(()=>{
            var watch=Stopwatch.StartNew();
            while(!lifetime.IsCancellationRequested&&watch.Elapsed.TotalSeconds<seconds)
                if(process.WaitForExit(100))return true;
            return process.HasExited;
        });
        if(!exited) { try{process.Kill(true);}catch{} }
        await Task.WhenAny(Task.WhenAll(stdoutDone.Task,stderrDone.Task),Task.Delay(1000));
        try{process.CancelOutputRead();}catch(InvalidOperationException){}
        try{process.CancelErrorRead();}catch(InvalidOperationException){}
        string output; lock(sync)output=text.ToString();
        if(!exited) { log("TIMEOUT: "+label+" ("+seconds+" s)\n"+Tail(output)); throw new TimeoutException("Komanda nije završena za "+seconds+" s:\n"+label+"\n"+Tail(output)+"\nKoristi Kopiraj dnevnik za detalje."); }
        if(!quiet)log("Završeno: "+Path.GetFileName(file)+" (kod "+process.ExitCode+")");
        return(process.ExitCode,output);
    }
    static async Task<string?> ServerVersionAsync(int port,CancellationToken token=default)
    {
        using var timeout=CancellationTokenSource.CreateLinkedTokenSource(token); timeout.CancelAfter(700);
        try
        {
            using var client=new TcpClient(); await client.ConnectAsync("127.0.0.1",port,timeout.Token);
            await using var stream=client.GetStream();
            await stream.WriteAsync(Encoding.ASCII.GetBytes("000chost:version"),timeout.Token);
            var status=new byte[4]; await stream.ReadExactlyAsync(status,timeout.Token);
            if(Encoding.ASCII.GetString(status)!="OKAY")return null;
            await stream.ReadExactlyAsync(status,timeout.Token);
            if(!int.TryParse(Encoding.ASCII.GetString(status),System.Globalization.NumberStyles.HexNumber,null,out var count)||count<1||count>64)return null;
            var version=new byte[count]; await stream.ReadExactlyAsync(version,timeout.Token);
            return Encoding.ASCII.GetString(version);
        }
        catch(Exception ex) when(ex is SocketException or IOException or OperationCanceledException) { return null; }
    }
    async Task EnsureAdbServerAsync()
    {
        if(!File.Exists(Adb))throw new FileNotFoundException("ADB nedostaje. Odaberi Pripremi Android.");
        if(await ServerVersionAsync(AdbPort,lifetime.Token)!=null)return;
        log("Pokrećem odvojeni Noria ADB server na 127.0.0.1:"+AdbPort+" (najviše 20 sekundi)…");
        var p=Info(Adb,new[]{"-L","tcp:127.0.0.1:"+AdbPort,"server","nodaemon"});
        p.RedirectStandardOutput=true; p.RedirectStandardError=true;
        var server=new Process { StartInfo=p };
        server.OutputDataReceived+=(_,e)=>{if(e.Data!=null)log("ADB: "+e.Data);};
        server.ErrorDataReceived+=(_,e)=>{if(e.Data!=null)log("ADB: "+e.Data);};
        adbServer=server;
        try
        {
            server.Start(); server.BeginOutputReadLine(); server.BeginErrorReadLine();
            var watch=Stopwatch.StartNew();
            while(watch.Elapsed.TotalSeconds<20&&!lifetime.IsCancellationRequested)
            {
                if(server.HasExited)throw new InvalidOperationException("Noria ADB server se zatvorio (kod "+server.ExitCode+"). Pogledaj ADB redove u dnevniku.");
                var version=await ServerVersionAsync(AdbPort,lifetime.Token);
                if(version!=null) { log("Noria ADB je spreman (protokol "+version+", port "+AdbPort+")."); return; }
                await Task.Delay(200,lifetime.Token);
            }
            throw new TimeoutException("Noria ADB nije odgovorio u roku od 20 sekundi. Provjeri ADB redove u dnevniku. Standardni ADB server na portu 5037 nije mijenjan.");
        }
        catch { StopOwnedServer(); throw; }
    }
    void StopOwnedServer()
    {
        var server=adbServer; adbServer=null; if(server==null)return;
        try { if(!server.HasExited)server.Kill(true); } catch { }
        server.Dispose();
    }
    public void ReleaseServer() { lifetime.Cancel(); StopOwnedServer(); }
    async Task Must(string file,IEnumerable<string> args,string? input=null)
    { var r=await Run(file,args,input); if(r.Code!=0)throw new InvalidOperationException("Operacija nije uspjela. Detalji su u dnevniku.\n"+Tail(r.Text)); }
    static string Tail(string s)=>s.Length>1800?s[^1800..]:s;
    public async Task SetupAsync()
    {
        if(!File.Exists(Path.Combine(Java,"bin","java.exe")))throw new FileNotFoundException("Nedostaje Java runtime. Raspakuj cijeli Noria Desktop ZIP, ne samo EXE.");
        if(new DriveInfo(Path.GetPathRoot(Root)!).AvailableFreeSpace<18L*1024*1024*1024)throw new InvalidOperationException("Za pripremu oslobodi najmanje 18 GB na disku sa korisničkim podacima.");
        Directory.CreateDirectory(Sdk); Directory.CreateDirectory(Avds); Directory.CreateDirectory(Path.Combine(Root,"android-user"));
        if(!File.Exists(Manager))
        {
            log("Preuzimanje zvaničnih Android alata sa Google servera…");
            using var client=new HttpClient { Timeout=TimeSpan.FromMinutes(30) };
            var doc=XDocument.Parse(await client.GetStringAsync("https://dl.google.com/android/repository/repository2-1.xml"));
            var package=doc.Descendants().First(x=>x.Name.LocalName=="remotePackage"&&(string?)x.Attribute("path")=="cmdline-tools;latest");
            var archive=package.Descendants().First(x=>x.Name.LocalName=="archive"&&x.Elements().Any(e=>e.Name.LocalName=="host-os"&&e.Value=="windows"));
            var complete=archive.Elements().First(x=>x.Name.LocalName=="complete");
            string Field(string n)=>complete.Elements().First(x=>x.Name.LocalName==n).Value.Trim();
            var relative=Field("url"); if(relative.Contains('/')||!relative.EndsWith(".zip"))throw new InvalidDataException("Neprepoznata putanja Android alata.");
            var zip=Path.Combine(Root,"commandline-tools.zip");
            using(var response=await client.GetAsync("https://dl.google.com/android/repository/"+relative,HttpCompletionOption.ResponseHeadersRead))
            { response.EnsureSuccessStatusCode(); await using var f=File.Create(zip); await response.Content.CopyToAsync(f); }
            await using(var f=File.OpenRead(zip))
            { var digest=Convert.ToHexString(await SHA1.HashDataAsync(f)); if(!digest.Equals(Field("checksum"),StringComparison.OrdinalIgnoreCase))throw new InvalidDataException("Kontrolni zbir preuzimanja nije ispravan."); }
            var temp=Path.Combine(Root,"tools-unpacked"); if(Directory.Exists(temp))Directory.Delete(temp,true);
            ZipFile.ExtractToDirectory(zip,temp); var latest=Path.Combine(Sdk,"cmdline-tools","latest"); Directory.CreateDirectory(Path.GetDirectoryName(latest)!);
            if(Directory.Exists(latest))Directory.Delete(latest,true); Directory.Move(Path.Combine(temp,"cmdline-tools"),latest); Directory.Delete(temp,true); File.Delete(zip);
        }
        log("Otvara se prozor Google licenci. Pročitaj uslove i odgovori y samo ako ih prihvataš. Licence se ne prihvataju automatski.");
        var license=Info(Manager,new[]{"--licenses"},true);
        using(var process=Process.Start(license)!) { await process.WaitForExitAsync(); if(process.ExitCode!=0)throw new InvalidOperationException("Licence nisu završene. Ponovi pripremu Androida."); }
        log("Instalacija emulatora i Android 15 slike. Ovo može potrajati nekoliko minuta…");
        await Must(Manager,new[]{"platform-tools","emulator",Image});
        if(!Directory.Exists(Path.Combine(Sdk,"system-images","android-35","google_apis","x86_64")))throw new InvalidOperationException("Android slika nije instalirana. Provjeri prihvatanje licenci.");
        if(!File.Exists(Path.Combine(Avds,Avd+".ini")))
        {
            await Must(Path.Combine(Sdk,"cmdline-tools","latest","bin","avdmanager.bat"),new[]{"create","avd","--name",Avd,"--package",Image,"--force"},"no\n");
            var config=Path.Combine(Avds,Avd+".avd","config.ini");
            SetIni(config,new Dictionary<string,string>{{"avd.ini.displayname","Noria Desktop"},{"hw.lcd.width","1920"},{"hw.lcd.height","1080"},{"hw.lcd.density","160"},{"hw.ramSize","4096"},{"hw.cpu.ncore","2"},{"hw.keyboard","yes"},{"hw.gpu.enabled","yes"},{"hw.gpu.mode","auto"},{"disk.dataPartition.size","6G"},{"showDeviceFrame","no"},{"skin.dynamic","yes"},{"skin.name","1920x1080"},{"hw.initialOrientation","landscape"}});
        }
        log("Android je pripremljen. Odaberi Pokreni Android.");
    }
    static void SetIni(string path,Dictionary<string,string> values)
    {
        var lines=File.ReadAllLines(path).Where(l=>!values.Keys.Any(k=>l.StartsWith(k+"=",StringComparison.Ordinal)||l.StartsWith(k+" =",StringComparison.Ordinal))).ToList();
        lines.AddRange(values.Select(k=>k.Key+"="+k.Value)); File.WriteAllLines(path,lines);
    }
    async Task<bool> IsOurDevice()
    {
        if(!File.Exists(Adb))return false;
        // Do not start/probe ADB when there is no emulator listening yet.
        using(var socket=new TcpClient())
        {
            try { await socket.ConnectAsync("127.0.0.1",5580).WaitAsync(TimeSpan.FromMilliseconds(700)); }
            catch(SocketException) { return false; }
            catch(TimeoutException) { return false; }
        }
        await EnsureAdbServerAsync();
        var state=await Run(Adb,new[]{"-s",Serial,"get-state"},seconds:15,quiet:true);
        if(state.Code!=0)return false;
        var name=await Run(Adb,new[]{"-s",Serial,"emu","avd","name"},seconds:15,quiet:true);
        if(!name.Text.Split('\n').Any(l=>l.Trim()==Avd))throw new InvalidOperationException("Port 5580 koristi drugi emulator. Zatvori ga prije pokretanja Norije.");
        return true;
    }
    async Task RequireDevice() { if(!await IsOurDevice())throw new InvalidOperationException("Prvo pokreni Noria Android i sačekaj završetak pokretanja."); }
    public async Task StartAsync(bool software)
    {
        if(!File.Exists(Emulator)||!File.Exists(Path.Combine(Avds,Avd+".ini")))throw new InvalidOperationException("Prvo odaberi Pripremi Android.");
        if(await IsOurDevice()) { log("Noria Android je već pokrenut."); return; }
        log("Provjera Windows ubrzanja…");
        var accel=await Run(Emulator,new[]{"-accel-check"},seconds:30);
        if(accel.Code!=0)throw new InvalidOperationException("Windows ubrzanje nije dostupno. Otvori Windows funkcije, uključi Windows Hypervisor Platform i restartuj PC.\n"+Tail(accel.Text));
        await EnsureAdbServerAsync();
        var p=Info(Emulator,new[]{"-avd",Avd,"-port","5580","-memory","4096","-cores","2","-gpu",software?"swiftshader_indirect":"auto","-no-boot-anim","-no-snapshot"});
        using var process=Process.Start(p)!;
        log("Čekam pokretanje Android sistema…");
        for(int i=0;i<100;i++)
        {
            await Task.Delay(3000);
            if(process.HasExited)throw new InvalidOperationException("Emulator se zatvorio. Pokušaj softverski prikaz i provjeru sistema.");
            var boot=await Run(Adb,new[]{"-s",Serial,"shell","getprop","sys.boot_completed"},seconds:10,quiet:true);
            if(boot.Code==0&&boot.Text.Trim()=="1") { await RequireDevice(); log("Android je spreman. Miš i tastatura rade u prozoru emulatora."); return; }
        }
        throw new TimeoutException("Android se nije pokrenuo na vrijeme. Pogledaj prozor emulatora i pokreni provjeru sistema.");
    }
    public async Task InstallAsync(string path)
    {
        await RequireDevice(); if(!File.Exists(path))throw new FileNotFoundException("APK nije pronađen.",path);
        log("Instalacija: "+Path.GetFileName(path)); await Must(Adb,new[]{"-s",Serial,"install","-r",path});
    }
    public async Task InstallBundledAsync()
    {
        var folder=Path.Combine(AppContext.BaseDirectory,"apks");
        foreach(var name in new[]{"BSL-1.0.0-Desktop.apk","NRN-Mesh-Pilot-1.3.0-Desktop.apk"}) await InstallAsync(Path.Combine(folder,name));
        log("BSL i NRN su instalirani. Izaberi aplikaciju lijevo.");
    }
    public async Task LaunchAsync(string package)
    {
        await RequireDevice();
        var result=await Run(Adb,new[]{"-s",Serial,"shell","monkey","-p",package,"-c","android.intent.category.LAUNCHER","1"});
        if(result.Code!=0||result.Text.Contains("No activities found"))throw new InvalidOperationException("Aplikacija nije pokrenuta. Prvo je instaliraj.\n"+Tail(result.Text));
    }
    public async Task StopAsync() { await RequireDevice(); await Must(Adb,new[]{"-s",Serial,"emu","kill"}); }
    public async Task DiagnosticsAsync()
    {
        log("Windows: "+Environment.OSVersion+" | CPU dostupno: "+Environment.ProcessorCount);
        log("Podaci: "+Root); log("Java: "+File.Exists(Path.Combine(Java,"bin","java.exe")));
        log("Slobodan prostor: "+new DriveInfo(Path.GetPathRoot(Root)!).AvailableFreeSpace/1024/1024/1024+" GB");
        if(File.Exists(Emulator)) { try { await Run(Emulator,new[]{"-accel-check"},seconds:45); } catch(Exception ex) { log("Provjera ubrzanja: "+ex.Message); } }
        else log("Android emulator još nije preuzet.");
        if(File.Exists(Adb)) { try { await EnsureAdbServerAsync(); await Run(Adb,new[]{"devices","-l"},seconds:15); } catch(Exception ex) { log("Provjera ADB: "+ex.Message); } }
    }
    public static int AdbSelfTest()
    {
        var e=new Engine(line=>Console.WriteLine(line));
        try
        {
            e.EnsureAdbServerAsync().GetAwaiter().GetResult();
            var r=e.Run(e.Adb,new[]{"devices","-l"},seconds:10).GetAwaiter().GetResult();
            if(r.Code!=0||!r.Text.Contains("List of devices attached"))return 10;
            // Reuse is fast and does not start an extra server.
            var watch=Stopwatch.StartNew(); e.EnsureAdbServerAsync().GetAwaiter().GetResult();
            if(watch.Elapsed.TotalSeconds>2)return 11;
            return 0;
        }
        catch(Exception ex) { File.WriteAllText(Path.Combine(e.Root,"adb-self-test-error.txt"),ex.ToString()); return 12; }
        finally { e.ReleaseServer(); }
    }
    public static int SelfTest()
    {
        var dir=Path.Combine(Path.GetTempPath(),"noria-test-"+Guid.NewGuid()); Directory.CreateDirectory(dir);
        try {
            var p=Path.Combine(dir,"config.ini"); File.WriteAllText(p,"hw.ramSize=1024\nhw.lcd.width = 800\nother=yes\n");
            SetIni(p,new(){{"hw.ramSize","4096"},{"hw.lcd.width","1920"}});
            var s=File.ReadAllText(p); if(!s.Contains("other=yes")||s.Contains("1024")||s.Contains("800"))return 1;
            if(Quote("C:\\path with spaces")!="\"C:\\path with spaces\"")return 2;
            try{Quote("bad%PATH%");return 3;}catch(InvalidOperationException){}
            var e=new Engine(_=>{}); var info=e.Info("C:\\tools with spaces\\sdkmanager.bat",new[]{Image});
            if(!info.Arguments.Contains("\""+Image+"\"")||info.Environment["ANDROID_AVD_HOME"]!=e.Avds)return 4;
            if(!File.Exists(Path.Combine(e.Java,"bin","java.exe")))return 5;
            var bat=Path.Combine(dir,"command with spaces.bat");
            File.WriteAllText(bat,"@echo off\r\necho %~1\r\n\"%JAVA_HOME%\\bin\\java.exe\" -version\r\nexit /b %errorlevel%\r\n");
            var result=e.Run(bat,new[]{Image},seconds:30,quiet:true).GetAwaiter().GetResult();
            if(result.Code!=0||!result.Text.Contains(Image)||!result.Text.Contains("openjdk"))return 6;
            // Regression: a command exits but a background child keeps its pipes open.
            var child=Path.Combine(dir,"background.bat");
            File.WriteAllText(child,"@echo off\r\nping -n 12 127.0.0.1 >nul\r\n");
            var parent=Path.Combine(dir,"parent.bat");
            File.WriteAllText(parent,"@echo off\r\nstart \"\" /b cmd /d /c \"\""+child+"\"\"\r\necho PARENT_FINISHED\r\nexit /b 0\r\n");
            var watch=Stopwatch.StartNew();
            var background=e.Run(parent,Array.Empty<string>(),seconds:5,quiet:true).GetAwaiter().GetResult();
            if(background.Code!=0||!background.Text.Contains("PARENT_FINISHED")||watch.Elapsed.TotalSeconds>4)return 7;
            // A genuine hung command must still time out, naming the offending command.
            try { e.Run(child,Array.Empty<string>(),seconds:1,quiet:true).GetAwaiter().GetResult(); return 8; }
            catch(TimeoutException ex) { if(!ex.Message.Contains("background.bat"))return 9; }
            return 0;
        } finally { try { Directory.Delete(dir,true); } catch(IOException) { } }
    }
}

