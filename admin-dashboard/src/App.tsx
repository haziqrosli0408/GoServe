import { useState, useEffect } from 'react';
import { auth, db } from './lib/firebase';
import { signInWithEmailAndPassword, onAuthStateChanged, signOut, type User } from 'firebase/auth';
import { getFunctions, httpsCallable } from 'firebase/functions';
import { 
  collection, 
  query, 
  onSnapshot, 
  doc, 
  updateDoc, 
  orderBy, 
  limit,
} from 'firebase/firestore';
import { 
  Users, 
  Star, 
  Briefcase, 
  BarChart3, 
  LogOut, 
  Calendar, 
  TrendingUp, 
  ShieldCheck,
  Menu,
  X,
  Search,
  Check,
  Ban,
  Trash2,
  Download,
  AlertCircle,
  Eye,
  EyeOff
} from 'lucide-react';
import { 
  BarChart, 
  Bar, 
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip, 
  ResponsiveContainer, 
  LineChart, 
  Line 
} from 'recharts';
import { PDFDownloadLink, Page, Text, View, Document, StyleSheet } from '@react-pdf/renderer';

// --- PDF COMPONENT ---
const styles = StyleSheet.create({
  page: { padding: 40, fontFamily: 'Helvetica', backgroundColor: '#ffffff' },
  header: { marginBottom: 30, borderBottom: '2pt solid #f97316', paddingBottom: 10 },
  title: { fontSize: 24, fontWeight: 'bold' },
  subtitle: { fontSize: 10, color: '#6b7280', marginTop: 4 },
  section: { marginTop: 20 },
  sectionTitle: { fontSize: 14, fontWeight: 'bold', marginBottom: 10 },
  table: { display: 'flex', width: 'auto', borderStyle: 'solid', borderWidth: 1, borderColor: '#e5e7eb' },
  tableRow: { flexDirection: 'row', borderBottomWidth: 1, borderColor: '#e5e7eb' },
  tableCell: { margin: 8, fontSize: 10 },
});

const ReportPDF = ({ users, services, reviews, bookings }: any) => (
  <Document>
    <Page size="A4" style={styles.page}>
      <View style={styles.header}>
        <Text style={styles.title}>GoServe Operational Report</Text>
        <Text style={styles.subtitle}>Generated on {new Date().toLocaleDateString()}</Text>
      </View>
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Overview Metrics</Text>
        <Text style={{ fontSize: 12 }}>Total Community: {users.length}</Text>
        <Text style={{ fontSize: 12 }}>Active Services: {services.length}</Text>
        <Text style={{ fontSize: 12 }}>Reviews Moderated: {reviews.length}</Text>
        <Text style={{ fontSize: 12 }}>Total Bookings: {bookings.length}</Text>
        <Text style={{ fontSize: 12 }}>Total Revenue: RM {bookings.reduce((acc: number, b: any) => acc + (b.totalPrice || 0), 0).toFixed(2)}</Text>
      </View>
    </Page>
  </Document>
);

// --- TYPES ---
interface AppUser {
  id: string;
  name: string;
  email: string;
  role: 'Seeker' | 'Professional';
  status: 'Active' | 'Suspended';
  profileUrl?: string;
}

interface Review {
  id: string;
  customerName: string;
  providerName: string;
  serviceName: string;
  rating: number;
  comment: string;
  status: 'Pending' | 'Approved' | 'Rejected';
  createdAt?: any;
}

interface Service {
  id: string;
  name: string;
  providerName: string;
  price: number;
  status: 'Active' | 'Hidden';
  category: string;
}

interface Booking {
  id: string;
  totalPrice: number;
  status: string;
  createdAt: any;
}

function App() {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('dashboard');
  const [sidebarOpen, setSidebarOpen] = useState(true);

  const [users, setUsers] = useState<AppUser[]>([]);
  const [services, setServices] = useState<Service[]>([]);
  const [reviews, setReviews] = useState<Review[]>([]);
  const [bookings, setBookings] = useState<Booking[]>([]);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (u) => {
      setUser(u);
      setLoading(false);
    });
    return unsubscribe;
  }, []);

  // Real-time listeners for all collections
  useEffect(() => {
    if (!user) return;

    const uUnsub = onSnapshot(collection(db, 'users'), (s) => setUsers(s.docs.map(d => ({ id: d.id, ...d.data(), role: 'Seeker' } as any))));
    const pUnsub = onSnapshot(collection(db, 'providers'), (s) => setUsers(prev => [...prev.filter(u => u.role !== 'Professional'), ...s.docs.map(d => ({ id: d.id, ...d.data(), role: 'Professional' } as any))]));
    const sUnsub = onSnapshot(collection(db, 'services'), (s) => setServices(s.docs.map(d => ({ id: d.id, ...d.data() } as any))));
    const rUnsub = onSnapshot(collection(db, 'reviews'), (s) => setReviews(s.docs.map(d => ({ id: d.id, ...d.data() } as any))));
    const bUnsub = onSnapshot(collection(db, 'bookings'), (s) => setBookings(s.docs.map(d => ({ id: d.id, ...d.data() } as any))));

    return () => { uUnsub(); pUnsub(); sUnsub(); rUnsub(); bUnsub(); };
  }, [user]);

  if (loading) return (
    <div className="h-screen w-screen flex items-center justify-center bg-gray-50">
      <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-orange-500"></div>
    </div>
  );

  if (!user) return <LoginPage />;

  return (
    <div className="flex h-screen bg-gray-50 overflow-hidden text-gray-900 font-sans">
      <aside className={`${sidebarOpen ? 'w-64' : 'w-20'} bg-white border-r border-gray-200 transition-all duration-300 flex flex-col z-20`}>
        <div className="p-6 flex items-center gap-3 shrink-0">
          <div className="w-8 h-8 bg-orange-500 rounded-lg flex items-center justify-center">
            <ShieldCheck size={20} className="text-white" />
          </div>
          {sidebarOpen && <span className="font-bold text-xl tracking-tight">GoServe Admin</span>}
        </div>

        <nav className="flex-1 px-4 space-y-1 mt-4 overflow-y-auto">
          <NavItem icon={<BarChart3 size={20} />} label="Dashboard" active={activeTab === 'dashboard'} collapsed={!sidebarOpen} onClick={() => setActiveTab('dashboard')} />
          <NavItem icon={<Users size={20} />} label="Users" active={activeTab === 'users'} collapsed={!sidebarOpen} onClick={() => setActiveTab('users')} />
          <NavItem icon={<Star size={20} />} label="Reviews" active={activeTab === 'reviews'} collapsed={!sidebarOpen} onClick={() => setActiveTab('reviews')} />
          <NavItem icon={<Briefcase size={20} />} label="Services" active={activeTab === 'services'} collapsed={!sidebarOpen} onClick={() => setActiveTab('services')} />
        </nav>

        <div className="p-4 border-t border-gray-100">
          <button onClick={() => signOut(auth)} className="flex items-center gap-3 w-full p-3 text-gray-500 hover:bg-red-50 hover:text-red-600 rounded-xl transition-all">
            <LogOut size={20} className="shrink-0" />
            {sidebarOpen && <span className="font-semibold text-sm">Logout</span>}
          </button>
        </div>
      </aside>

      <main className="flex-1 flex flex-col overflow-hidden">
        <header className="h-16 bg-white border-b border-gray-200 px-8 flex items-center justify-between shrink-0">
          <div className="flex items-center gap-4">
            <button onClick={() => setSidebarOpen(!sidebarOpen)} className="p-2 hover:bg-gray-100 rounded-lg text-gray-500">
              {sidebarOpen ? <X size={20} /> : <Menu size={20} />}
            </button>
            <h2 className="font-bold text-gray-800 capitalize hidden sm:block">{activeTab}</h2>
          </div>
          
          <div className="flex items-center gap-4">
            <div className="text-right hidden sm:block">
              <p className="text-sm font-bold text-gray-900">Administrator</p>
              <p className="text-[10px] text-orange-500 font-bold uppercase tracking-widest">Master Access</p>
            </div>
            <div className="w-10 h-10 rounded-2xl bg-orange-500 flex items-center justify-center text-white font-bold shadow-lg shadow-orange-200">
              AD
            </div>
          </div>
        </header>

        <section className="flex-1 overflow-y-auto bg-gray-50/50 p-4 sm:p-8">
          <TabContent 
            activeTab={activeTab} 
            data={{ users, services, reviews, bookings }}
          />
        </section>
      </main>
    </div>
  );
}

function NavItem({ icon, label, active, onClick, collapsed }: any) {
  return (
    <button 
      onClick={onClick}
      className={`flex items-center gap-3 w-full p-3 rounded-xl transition-all duration-300 relative group ${
        active 
          ? 'bg-orange-500 text-white shadow-lg shadow-orange-200' 
          : 'text-gray-500 hover:bg-gray-50'
      }`}
    >
      <div className="shrink-0">{icon}</div>
      {!collapsed && <span className="font-semibold text-sm">{label}</span>}
    </button>
  );
}

function TabContent({ activeTab, data }: any) {
  switch (activeTab) {
    case 'dashboard': return <DashboardPage data={data} />;
    case 'users': return <UsersPage users={data.users} />;
    case 'reviews': return <ReviewsPage reviews={data.reviews} />;
    case 'services': return <ServicesPage services={data.services} />;
    default: return <DashboardPage data={data} />;
  }
}

function DashboardPage({ data }: any) {
  const { users, services, reviews, bookings } = data;

  const totalRevenue = bookings.reduce((acc: number, b: any) => acc + (Number(b.totalPrice) || 0), 0);
  const completedBookings = bookings.filter((b: any) => b.status === 'Completed' || b.status === 'Success').length;
  const avgRating = reviews.length > 0 ? (reviews.reduce((acc: number, r: any) => acc + (r.rating || 0), 0) / reviews.length).toFixed(1) : "0.0";

  // Process data for charts
  const revenueByDay = bookings.reduce((acc: any, b: any) => {
    if (!b.createdAt) return acc;
    const date = new Date(b.createdAt.seconds * 1000).toLocaleDateString('en-US', { weekday: 'short' });
    acc[date] = (acc[date] || 0) + (Number(b.totalPrice) || 0);
    return acc;
  }, {});

  const chartData = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map(day => ({
    name: day,
    revenue: revenueByDay[day] || 0
  }));

  return (
    <div className="space-y-8">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 tracking-tight">System Analytics</h1>
          <p className="text-gray-500 text-sm font-medium">Real-time ecosystem intelligence</p>
        </div>
        
        <PDFDownloadLink 
          document={<ReportPDF users={users} services={services} reviews={reviews} bookings={bookings} />} 
          fileName="GoServe_Platform_Report.pdf"
          className="bg-gray-900 text-white px-6 py-3 rounded-xl font-bold text-sm shadow-xl hover:bg-gray-800 transition-all flex items-center gap-2"
        >
          {({ loading }) => (
            <>
              <Download size={18} />
              {loading ? 'Preparing Report...' : 'Generate PDF Report'}
            </>
          )}
        </PDFDownloadLink>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard label="Total Community" value={users.length.toLocaleString()} trend="+Real-time" icon={<Users size={20} />} color="bg-blue-500" />
        <StatCard label="Total Revenue" value={`RM ${totalRevenue.toLocaleString(undefined, { minimumFractionDigits: 2 })}`} trend="+Actual" icon={<TrendingUp size={20} />} color="bg-emerald-500" />
        <StatCard label="Serviced Orders" value={completedBookings.toLocaleString()} trend="+Actual" icon={<Calendar size={20} />} color="bg-orange-500" />
        <StatCard label="Review Sentiment" value={avgRating} trend="Out of 5" icon={<Star size={20} />} color="bg-amber-500" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        <div className="bg-white p-8 rounded-3xl border border-gray-100 shadow-sm">
          <h3 className="font-bold text-gray-900 mb-8 flex items-center gap-2">
            <TrendingUp size={18} className="text-emerald-500" />
            Revenue Distribution
          </h3>
          <div className="h-80 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9" />
                <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{fontSize: 12, fill: '#94a3b8'}} dy={10} />
                <YAxis axisLine={false} tickLine={false} tick={{fontSize: 12, fill: '#94a3b8'}} />
                <Tooltip 
                   contentStyle={{borderRadius: '16px', border: 'none', boxShadow: '0 10px 15px -3px rgb(0 0 0 / 0.1)'}}
                />
                <Line type="monotone" dataKey="revenue" stroke="#10b981" strokeWidth={3} dot={{r: 4, fill: '#10b981', strokeWidth: 2, stroke: '#fff'}} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="bg-white p-8 rounded-3xl border border-gray-100 shadow-sm">
          <h3 className="font-bold text-gray-900 mb-8 flex items-center gap-2">
            <Users size={18} className="text-blue-500" />
            Order Volume
          </h3>
          <div className="h-80 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9" />
                <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{fontSize: 12, fill: '#94a3b8'}} dy={10} />
                <YAxis axisLine={false} tickLine={false} tick={{fontSize: 12, fill: '#94a3b8'}} />
                <Tooltip 
                  contentStyle={{borderRadius: '16px', border: 'none', boxShadow: '0 10px 15px -3px rgb(0 0 0 / 0.1)'}}
                />
                <Bar dataKey="revenue" fill="#3b82f6" radius={[6, 6, 0, 0]} barSize={20} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>
    </div>
  );
}

function StatCard({ label, value, trend, icon, color }: any) {
  return (
    <div className="bg-white p-6 rounded-[2rem] border border-gray-100 shadow-sm">
      <div className="flex justify-between items-start mb-4">
        <div className={`p-3 rounded-2xl ${color} text-white shadow-lg`}>
          {icon}
        </div>
        <span className="text-gray-400 text-[10px] font-bold px-2 py-1 bg-gray-50 rounded-full">{trend}</span>
      </div>
      <p className="text-gray-500 text-xs font-medium uppercase tracking-wider mb-1">{label}</p>
      <p className="text-2xl font-bold text-gray-900">{value}</p>
    </div>
  );
}

function UsersPage({ users }: any) {
  const [search, setSearch] = useState('');
  const [actionLoading, setActionLoading] = useState<string | null>(null);

  const handleAction = async (uid: string, role: string, action: 'delete' | 'suspend' | 'activate') => {
    if (!window.confirm(`Are you sure you want to ${action} this account?`)) return;
    
    setActionLoading(uid);
    try {
      const functions = getFunctions();
      if (action === 'delete') {
        const deleteFn = httpsCallable(functions, 'deleteUser');
        await deleteFn({ uid, role });
      } else {
        const toggleFn = httpsCallable(functions, 'toggleUserStatus');
        await toggleFn({ uid, role, status: action === 'suspend' ? 'Suspended' : 'Active' });
      }
    } catch (e: any) {
      alert(`Action failed: ${e.message}`);
    } finally {
      setActionLoading(null);
    }
  };

  const filteredUsers = users.filter((u: any) => 
    u.name?.toLowerCase().includes(search.toLowerCase()) || 
    u.email?.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 uppercase">Community</h1>
          <p className="text-gray-500 text-sm font-medium">Monitoring Seekers & Professionals</p>
        </div>
        <div className="relative w-full sm:w-80">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={16} />
          <input 
            type="text" 
            placeholder="Search users..." 
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-10 pr-4 py-2 border rounded-xl text-gray-900"
          />
        </div>
      </div>

      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
        <table className="w-full text-left">
          <thead>
            <tr className="bg-gray-50/50">
              <th className="px-6 py-4 text-xs font-bold uppercase text-gray-400">User Profile</th>
              <th className="px-6 py-4 text-xs font-bold uppercase text-gray-400">Role</th>
              <th className="px-6 py-4 text-xs font-bold uppercase text-gray-400">Status</th>
              <th className="px-6 py-4 text-xs font-bold uppercase text-gray-400 text-right">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-50">
            {users.length === 0 ? (
               <tr><td colSpan={4} className="p-12 text-center text-gray-400">Loading Directory...</td></tr>
            ) : filteredUsers.map((u: any) => (
              <tr key={u.id} className="hover:bg-gray-50/50 transition-colors group">
                <td className="px-6 py-4">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-full bg-gray-100 flex items-center justify-center font-bold text-gray-400">
                      {u.name?.[0]?.toUpperCase()}
                    </div>
                    <div>
                      <p className="font-bold text-sm text-gray-900">{u.name || 'Anonymous'}</p>
                      <p className="text-xs text-gray-400">{u.email}</p>
                    </div>
                  </div>
                </td>
                <td className="px-6 py-4">
                  <span className={`px-2 py-1 rounded-full text-[10px] font-bold uppercase ${
                    u.role === 'Professional' ? 'bg-indigo-50 text-indigo-600' : 'bg-orange-50 text-orange-600'
                  }`}>
                    {u.role}
                  </span>
                </td>
                <td className="px-6 py-4 text-xs font-bold text-gray-600">
                  {u.status || 'Active'}
                </td>
                <td className="px-6 py-4 text-right">
                   <div className="flex items-center justify-end gap-2 opacity-0 group-hover:opacity-100">
                    {actionLoading === u.id ? (
                      <div className="animate-spin h-5 w-5 border-2 border-orange-500 border-t-transparent"></div>
                    ) : (
                      <>
                        <button 
                          onClick={() => handleAction(u.id, u.role, u.status === 'Suspended' ? 'activate' : 'suspend')}
                          className={`p-2 rounded-lg ${u.status === 'Suspended' ? 'text-emerald-600' : 'text-amber-600'}`}
                        >
                          {u.status === 'Suspended' ? <Check size={18} /> : <Ban size={18} />}
                        </button>
                        <button 
                          onClick={() => handleAction(u.id, u.role, 'delete')}
                          className="p-2 rounded-lg text-red-600"
                        >
                          <Trash2 size={18} />
                        </button>
                      </>
                    )}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function ReviewsPage({ reviews }: any) {
  const handleStatus = async (id: string, status: 'Approved' | 'Rejected') => {
    try {
      await updateDoc(doc(db, 'reviews', id), { status });
    } catch (e) {
      console.error(e);
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900 uppercase">Review Board</h1>
        <p className="text-gray-500 text-sm font-medium">Moderating Marketplace Veracity</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {reviews.length === 0 ? (
          <div className="col-span-full p-20 text-center text-gray-400">No Reviews to moderate.</div>
        ) : reviews.map((r: any) => (
          <div key={r.id} className="bg-white p-6 rounded-3xl border border-gray-100 shadow-sm">
            <div className="flex justify-between items-start mb-4">
              <div className="flex items-center gap-1">
                {[...Array(5)].map((_, i) => (
                  <Star key={i} size={14} fill={i < r.rating ? "#f59e0b" : "#e2e8f0"} className={i < r.rating ? "text-amber-500" : "text-gray-200"} />
                ))}
              </div>
              <span className={`text-[10px] font-bold uppercase px-2 py-1 rounded-lg ${
                r.status === 'Approved' ? 'bg-emerald-50 text-emerald-600' : r.status === 'Rejected' ? 'bg-red-50 text-red-600' : 'bg-orange-50 text-orange-600'
              }`}>
                {r.status || 'Pending'}
              </span>
            </div>
            <p className="font-bold text-gray-900">{r.serviceName || 'Service'}</p>
            <p className="text-xs text-gray-600 mb-6 italic">"{r.comment}"</p>
            <div className="flex gap-2">
              <button onClick={() => handleStatus(r.id, 'Approved')} className="flex-1 py-2 bg-emerald-500 text-white rounded-xl font-bold text-xs">Approve</button>
              <button onClick={() => handleStatus(r.id, 'Rejected')} className="flex-1 py-2 border border-gray-100 text-red-500 rounded-xl font-bold text-xs">Reject</button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function ServicesPage({ services }: any) {
  const toggleStatus = async (id: string, current: string) => {
    try {
      await updateDoc(doc(db, 'services', id), { 
        status: current === 'Active' ? 'Hidden' : 'Active' 
      });
    } catch (e) {
      console.error(e);
    }
  };

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-gray-900 uppercase">Services</h1>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
        {services.length === 0 ? (
          <div className="col-span-full p-20 text-center text-gray-400">No Services found.</div>
        ) : services.map((s: any) => (
          <div key={s.id} className="bg-white rounded-3xl border border-gray-100 shadow-sm overflow-hidden p-5">
            <h4 className="font-bold text-gray-900 mb-4">{s.name}</h4>
            <div className="flex items-center justify-between">
              <span className="text-sm font-bold text-gray-900">RM {Number(s.price || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
              <button 
                onClick={() => toggleStatus(s.id, s.status || 'Active')}
                className={`p-2 rounded-xl transition-all ${
                  s.status === 'Active' ? 'bg-gray-50 text-gray-400' : 'bg-orange-500 text-white'
                }`}
              >
                {s.status === 'Active' ? <Ban size={18} /> : <Check size={18} />}
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function LoginPage() {
  const [email, setEmail] = useState('admin@goserve.com');
  const [password, setPassword] = useState('AdminGoServe123');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      await signInWithEmailAndPassword(auth, email, password);
    } catch (err: any) {
      setError('Invalid credentials.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="h-screen w-screen flex items-center justify-center bg-gray-50 text-gray-900">
      <div className="w-full max-w-sm bg-white rounded-[2.5rem] p-10 shadow-xl text-center">
        <div className="w-20 h-20 bg-orange-500 rounded-3xl flex items-center justify-center mx-auto mb-8 shadow-lg shadow-orange-100">
          <ShieldCheck size={40} className="text-white" />
        </div>
        <h2 className="text-3xl font-bold text-gray-900 mb-2">Welcome Back</h2>
        <p className="text-gray-500 text-sm mb-10">Login to access the admin console</p>
        
        {error && <div className="mb-6 p-3 bg-red-50 text-red-500 text-xs font-bold rounded-xl border border-red-100">{error}</div>}
        
        <form onSubmit={handleLogin} className="space-y-6 text-left">
           <div className="space-y-2">
            <label className="text-[13px] font-medium text-gray-500 px-1">Email address</label>
            <input 
              type="email" 
              value={email} 
              onChange={(e) => setEmail(e.target.value)} 
              className="w-full px-5 py-4 bg-gray-50 border-none rounded-2xl focus:outline-none focus:ring-2 focus:ring-orange-500 font-medium text-base text-gray-900 transition-all placeholder:text-gray-300" 
              placeholder="name@example.com"
              required 
            />
          </div>
          
          <div className="space-y-2">
            <label className="text-[13px] font-medium text-gray-500 px-1">Password</label>
            <div className="relative">
              <input 
                type={showPassword ? "text" : "password"} 
                value={password} 
                onChange={(e) => setPassword(e.target.value)} 
                className="w-full px-5 py-4 bg-gray-50 border-none rounded-2xl focus:outline-none focus:ring-2 focus:ring-orange-500 font-medium text-base text-gray-900 transition-all" 
                placeholder="••••••••••••"
                required 
              />
              <button 
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 focus:outline-none transition-colors"
              >
                {showPassword ? <EyeOff size={20} /> : <Eye size={20} />}
              </button>
            </div>
          </div>
          
          <button type="submit" disabled={loading} className="w-full py-4.5 bg-orange-500 text-white rounded-2xl font-bold text-base shadow-lg shadow-orange-100 hover:bg-orange-600 active:scale-[0.98] transition-all mt-4">
            {loading ? 'Entering System...' : 'Login'}
          </button>
        </form>
      </div>
    </div>
  );
}

export default App;
