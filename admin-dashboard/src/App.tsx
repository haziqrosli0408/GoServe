import { useState, useEffect, useMemo } from 'react';
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
  getDocs,
  writeBatch,
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
  Eye,
  EyeOff,
  UserCheck,
  MoreVertical,
  ChevronLeft,
  ChevronRight,
  RotateCcw,
  FileText,
  MapPin,
  Phone,
  Mail,
  ArrowLeft,
  DollarSign,
  Clock,
  Bookmark,
  LayoutGrid,
  List,
  CreditCard,
  Wallet,
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
  Line,
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
  customId?: string;
  name: string;
  email: string;
  role: 'Seeker' | 'Professional';
  status: 'Active' | 'Suspended';
  profileUrl?: string;
  createdAt?: any;
  customId?: string;
  verificationStatus?: 'verified' | 'pending' | 'rejected' | string;
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
  title: string;
  providerName: string;
  providerId: string;
  price: string | number;
  isActive: boolean;
  category: string;
  description?: string;
  servicePhotoUrl?: string;
  details?: string[];
  addOns?: { name: string; price: string | number }[];
  galleryUrls?: string[];
  customId?: string;
}

interface Booking {
  id: string;
  orderId: string;
  customerId: string;
  providerId: string;
  providerName: string;
  serviceName: string;
  serviceId: string;
  category: string;
  serviceImage?: string;
  date: string;
  time: string;
  address: string;
  totalPrice: number;
  basePrice: number;
  chargeFee: number;
  paymentMethod: string;
  status: 'Pending' | 'Confirmed' | 'In Progress' | 'Completed' | 'Cancelled';
  createdAt: any;
  selectedAddOns?: { name: string; price: string | number }[];
}

interface Report {
  id: string;
  orderId: string;
  bookingId: string;
  serviceName: string;
  customerId: string;
  customerCustomId?: string;
  customerName: string;
  customerProfileUrl?: string;
  providerId: string;
  providerCustomId?: string;
  providerName: string;
  issue: string;
  status: 'pending' | 'resolved';
  timestamp: any;
}

interface VerificationRequest {
  id: string;
  name: string;
  email: string;
  selfieUrl: string;
  icFrontUrl?: string;
  icBackUrl?: string;
  icUrl?: string; // Legacy field
  address?: string;
}

function App() {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('dashboard');
  const [sidebarOpen, setSidebarOpen] = useState(true);

  const [seekers, setSeekers] = useState<AppUser[]>([]);
  const [providers, setProviders] = useState<AppUser[]>([]);
  const [services, setServices] = useState<Service[]>([]);
  const [reviews, setReviews] = useState<Review[]>([]);
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [verifications, setVerifications] = useState<VerificationRequest[]>([]);
  const [reports, setReports] = useState<Report[]>([]);

  const users = useMemo(() => {
    const userMap = new Map<string, AppUser>();
    
    // Add seekers first (base data)
    seekers.forEach(s => userMap.set(s.id, { ...s }));
    
    // Add providers, merging only if it's a valid provider record
    providers.forEach(p => {
      const existing = userMap.get(p.id);
      
      // If they are in both, only upgrade to 'provider' if the provider record is substantial
      // or if they don't exist in the users collection yet.
      const isActuallyProvider = p.customId || !existing;
      
      userMap.set(p.id, {
        ...existing,
        ...p,
        role: isActuallyProvider ? (p.role || 'provider') : (existing?.role || 'customer')
      });
    });
    
    return Array.from(userMap.values());
  }, [seekers, providers]);

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

    const uUnsub = onSnapshot(collection(db, 'users'), (s) => setSeekers(s.docs.map(d => {
      const data = d.data();
      return { id: d.id, ...data, role: data.role || 'customer' } as any;
    })));
    const pUnsub = onSnapshot(collection(db, 'providers'), (s) => setProviders(s.docs.map(d => {
      const data = d.data();
      return { id: d.id, ...data, role: data.role || 'provider' } as any;
    })));
    const sUnsub = onSnapshot(collection(db, 'services'), (s) => setServices(s.docs.map(d => ({ id: d.id, ...d.data() } as any))));
    const rUnsub = onSnapshot(collection(db, 'reviews'), (s) => setReviews(s.docs.map(d => ({ id: d.id, ...d.data() } as any))));
    const bUnsub = onSnapshot(collection(db, 'bookings'), (s) => setBookings(s.docs.map(d => ({ id: d.id, ...d.data() } as any))));
    const vUnsub = onSnapshot(query(collection(db, 'providers'), orderBy('name')), (s) => {
      setVerifications(s.docs
        .filter(d => d.data().verificationStatus === 'pending')
        .map(d => ({ id: d.id, ...d.data() } as any))
      );
    });
    const rptsUnsub = onSnapshot(query(collection(db, 'reports'), orderBy('timestamp', 'desc')), (s) => {
      setReports(s.docs.map(d => ({ id: d.id, ...d.data() } as any)));
    });

    return () => { uUnsub(); pUnsub(); sUnsub(); rUnsub(); bUnsub(); vUnsub(); rptsUnsub(); };
  }, [user]);

  if (loading) return (
    <div className="h-screen w-screen flex items-center justify-center bg-gray-50">
      <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-orange-500"></div>
    </div>
  );

  if (!user) return <LoginPage />;

  return (
    <div className="flex h-screen bg-gray-50 overflow-hidden text-gray-900 font-sans">
      <aside className={`${sidebarOpen ? 'w-56' : 'w-20'} bg-white border-r border-gray-200 transition-all duration-300 flex flex-col z-20`}>
        <div className="p-6 flex items-center gap-3 shrink-0">
          <div className="w-8 h-8 bg-orange-500 rounded flex items-center justify-center">
            <ShieldCheck size={20} className="text-white" />
          </div>
          {sidebarOpen && <span className="font-bold text-xl tracking-tight">GoServe</span>}
        </div>

        <nav className="flex-1 px-4 space-y-1 mt-4 overflow-y-auto">
          <NavItem icon={<BarChart3 size={20} />} label="Dashboard" active={activeTab === 'dashboard'} collapsed={!sidebarOpen} onClick={() => setActiveTab('dashboard')} />
          <NavItem icon={<Users size={20} />} label="Users" active={activeTab === 'users'} collapsed={!sidebarOpen} onClick={() => setActiveTab('users')} />
          <NavItem icon={<UserCheck size={20} />} label="Verification" active={activeTab === 'verification'} collapsed={!sidebarOpen} onClick={() => setActiveTab('verification')} />
          <NavItem icon={<Briefcase size={20} />} label="Services" active={activeTab === 'services'} collapsed={!sidebarOpen} onClick={() => setActiveTab('services')} />
          <NavItem icon={<Calendar size={20} />} label="Bookings" active={activeTab === 'bookings'} collapsed={!sidebarOpen} onClick={() => setActiveTab('bookings')} />
          <NavItem icon={<Star size={20} />} label="Reviews" active={activeTab === 'reviews'} collapsed={!sidebarOpen} onClick={() => setActiveTab('reviews')} />
          <NavItem icon={<FileText size={20} />} label="Reports" active={activeTab === 'reports'} collapsed={!sidebarOpen} onClick={() => setActiveTab('reports')} />
        </nav>

        <div className="p-4 border-t border-gray-100 mt-auto">
          <button 
            onClick={() => setSidebarOpen(!sidebarOpen)} 
            className="flex items-center justify-center w-full p-3 text-gray-400 hover:bg-gray-50 hover:text-orange-500 rounded-md transition-all"
          >
            {sidebarOpen ? <ChevronLeft size={20} /> : <ChevronRight size={20} />}
          </button>
        </div>
      </aside>

      <main className="flex-1 flex flex-col overflow-hidden">
        <header className="h-16 bg-white border-b border-gray-200 px-8 flex items-center justify-between shrink-0">
          <div className="flex items-center gap-4">
            <h2 className="font-bold text-sm text-gray-800 capitalize hidden sm:block">{activeTab}</h2>
          </div>

          <div className="flex items-center gap-4">
            <div className="text-right hidden sm:block">
              <p className="text-sm font-bold text-gray-900">Administrator</p>
              <p className="text-[10px] text-orange-500 font-bold uppercase tracking-widest">Master Access</p>
            </div>
            <div className="w-10 h-10 rounded-lg bg-orange-500 flex items-center justify-center text-white font-bold shadow-lg shadow-orange-200">
              AD
            </div>
            <div className="h-8 w-[1px] bg-gray-200 mx-2" />
            <button 
              onClick={() => signOut(auth)} 
              className="p-2.5 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-all"
              title="Logout"
            >
              <LogOut size={20} />
            </button>
          </div>
        </header>

        <section className="flex-1 overflow-y-auto bg-gray-50/50 p-4 sm:p-8">
          <TabContent
            activeTab={activeTab}
            setActiveTab={setActiveTab}
            data={{ users, services, reviews, bookings, verifications, reports }}
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
      className={`flex items-center gap-3 w-full p-3 rounded-md transition-all duration-300 relative group ${active
          ? 'bg-gray-100 text-orange-500 font-bold'
          : 'text-gray-500 hover:bg-gray-50 font-semibold'
        }`}
    >
      <div className="shrink-0">{icon}</div>
      {!collapsed && <span className="font-semibold text-sm">{label}</span>}
    </button>
  );
}

function TabContent({ activeTab, data, setActiveTab }: any) {
  switch (activeTab) {
    case 'dashboard': return <DashboardPage data={data} setActiveTab={setActiveTab} />;
    case 'users': return <UsersPage users={data.users} bookings={data.bookings} reviews={data.reviews} pendingApprovalsCount={data.verifications.length} />;
    case 'reviews': return <ReviewsPage reviews={data.reviews} />;
    case 'services': return <ServicesPage services={data.services} users={data.users} bookings={data.bookings} reviews={data.reviews} />;
    case 'bookings': return <BookingsPage bookings={data.bookings} users={data.users} services={data.services} />;
    case 'verification': return <VerificationPage requests={data.verifications} />;
    case 'reports': return <ReportsPage reports={data.reports} />;
    default: return <DashboardPage data={data} />;
  }
}

function BookingsPage({ bookings, users, services }: { bookings: Booking[], users: AppUser[], services: Service[] }) {
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('All');
  const [selectedBooking, setSelectedBooking] = useState<Booking | null>(null);

  const filteredBookings = bookings.filter(b => {
    const seeker = users.find(u => u.id === b.customerId);
    const matchesSearch = 
      b.orderId?.toLowerCase().includes(search.toLowerCase()) ||
      b.serviceName?.toLowerCase().includes(search.toLowerCase()) ||
      b.providerName?.toLowerCase().includes(search.toLowerCase()) ||
      seeker?.name?.toLowerCase().includes(search.toLowerCase());
    
    const matchesStatus = statusFilter === 'All' || b.status === statusFilter;
    return matchesSearch && matchesStatus;
  }).sort((a, b) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0));

  const stats = {
    total: bookings.length,
    active: bookings.filter(b => ['Confirmed', 'In Progress'].includes(b.status)).length,
    completed: bookings.filter(b => b.status === 'Completed').length,
    revenue: bookings.filter(b => b.status === 'Completed').reduce((acc, b) => acc + (b.totalPrice || 0), 0)
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'Pending': return 'bg-amber-50 text-amber-600 border-amber-100';
      case 'Confirmed': return 'bg-blue-50 text-blue-600 border-blue-100';
      case 'In Progress': return 'bg-indigo-50 text-indigo-600 border-indigo-100';
      case 'Completed': return 'bg-emerald-50 text-emerald-600 border-emerald-100';
      case 'Cancelled': return 'bg-rose-50 text-rose-600 border-rose-100';
      default: return 'bg-gray-50 text-gray-600 border-gray-100';
    }
  };

  return (
    <div className="space-y-6">
      {/* HEADER & STATS */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white p-5 rounded-xl border border-gray-100 shadow-sm">
          <div className="flex items-center gap-4">
            <div className="p-3 bg-blue-50 text-blue-600 rounded-lg">
              <Calendar size={24} />
            </div>
            <div>
              <p className="text-xs font-bold text-gray-400 uppercase tracking-widest">Total Bookings</p>
              <h3 className="text-2xl font-black text-gray-900">{stats.total}</h3>
            </div>
          </div>
        </div>
        <div className="bg-white p-5 rounded-xl border border-gray-100 shadow-sm">
          <div className="flex items-center gap-4">
            <div className="p-3 bg-indigo-50 text-indigo-600 rounded-lg">
              <Clock size={24} />
            </div>
            <div>
              <p className="text-xs font-bold text-gray-400 uppercase tracking-widest">Active Now</p>
              <h3 className="text-2xl font-black text-gray-900">{stats.active}</h3>
            </div>
          </div>
        </div>
        <div className="bg-white p-5 rounded-xl border border-gray-100 shadow-sm">
          <div className="flex items-center gap-4">
            <div className="p-3 bg-emerald-50 text-emerald-600 rounded-lg">
              <Check size={24} />
            </div>
            <div>
              <p className="text-xs font-bold text-gray-400 uppercase tracking-widest">Completed</p>
              <h3 className="text-2xl font-black text-gray-900">{stats.completed}</h3>
            </div>
          </div>
        </div>
        <div className="bg-white p-5 rounded-xl border border-gray-100 shadow-sm">
          <div className="flex items-center gap-4">
            <div className="p-3 bg-orange-50 text-orange-600 rounded-lg">
              <DollarSign size={24} />
            </div>
            <div>
              <p className="text-xs font-bold text-gray-400 uppercase tracking-widest">Total GMV</p>
              <h3 className="text-2xl font-black text-gray-900">RM {stats.revenue.toLocaleString()}</h3>
            </div>
          </div>
        </div>
      </div>

      {/* FILTERS */}
      <div className="bg-white p-4 rounded-xl border border-gray-100 shadow-sm flex flex-col md:flex-row items-center justify-between gap-4">
        <div className="relative flex-1 w-full max-w-md">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
          <input
            type="text"
            placeholder="Search Order ID, Service, Provider or Customer..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-10 pr-4 py-2.5 bg-gray-50 border border-gray-200 rounded-lg text-sm font-medium focus:outline-none focus:ring-2 focus:ring-orange-500/20 transition-all"
          />
        </div>
        <div className="flex items-center gap-2 overflow-x-auto w-full md:w-auto pb-2 md:pb-0">
          {['All', 'Pending', 'Confirmed', 'In Progress', 'Completed', 'Cancelled'].map((status) => (
            <button
              key={status}
              onClick={() => setStatusFilter(status)}
              className={`px-4 py-2 rounded-lg text-xs font-bold transition-all whitespace-nowrap ${statusFilter === status
                  ? 'bg-orange-500 text-white shadow-lg shadow-orange-100'
                  : 'bg-gray-100 text-gray-500 hover:bg-gray-200'
                }`}
            >
              {status}
            </button>
          ))}
        </div>
      </div>

      {/* TABLE */}
      <div className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left">
            <thead>
              <tr className="bg-gray-50/50 border-b border-gray-100">
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest">Booking Info</th>
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest">Customer</th>
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest text-center">Status</th>
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest">Payment</th>
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest">Scheduled</th>
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {filteredBookings.map((b) => {
                const seeker = users.find(u => u.id === b.customerId);
                const platformFee = b.chargeFee || (b.totalPrice * 0.15);
                const providerEarnings = b.totalPrice - platformFee;

                return (
                  <tr key={b.id} className="hover:bg-gray-50/50 transition-colors">
                    <td className="px-6 py-4">
                      <div>
                        <p className="text-xs font-black text-orange-600 mb-1">{b.orderId || b.id.substring(0, 8)}</p>
                        <p className="text-sm font-bold text-gray-900 truncate max-w-[200px]">{b.serviceName}</p>
                        <p className="text-[10px] font-medium text-gray-400">by {b.providerName}</p>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-full bg-gray-100 flex items-center justify-center text-xs font-bold text-gray-500">
                          {seeker?.name?.[0] || 'C'}
                        </div>
                        <div>
                          <p className="text-sm font-bold text-gray-900">{seeker?.name || 'Customer'}</p>
                          <p className="text-[10px] font-medium text-gray-400">{seeker?.customId || 'Seeker'}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex justify-center">
                        <span className={`px-2.5 py-1 rounded-full text-[10px] font-bold border uppercase tracking-wider ${getStatusColor(b.status)}`}>
                          {b.status}
                        </span>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div>
                        <p className="text-sm font-bold text-gray-900">RM {b.totalPrice?.toFixed(2)}</p>
                        <div className="flex items-center gap-1.5 mt-1">
                          <span className="text-[9px] font-bold text-emerald-600 bg-emerald-50 px-1 rounded uppercase tracking-tighter">Pro: RM {providerEarnings.toFixed(2)}</span>
                          <span className="text-[9px] font-bold text-indigo-600 bg-indigo-50 px-1 rounded uppercase tracking-tighter">Fee: RM {platformFee.toFixed(2)}</span>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex flex-col gap-1">
                        <div className="flex items-center gap-1 text-xs font-bold text-gray-700">
                          <Calendar size={12} className="text-orange-500" />
                          {b.date}
                        </div>
                        <div className="flex items-center gap-1 text-[10px] font-medium text-gray-400 uppercase tracking-widest">
                          <Clock size={12} />
                          {b.time}
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-right">
                      <button 
                        onClick={() => setSelectedBooking(b)}
                        className="p-2 text-gray-400 hover:text-orange-500 hover:bg-orange-50 rounded-lg transition-all"
                      >
                        <Eye size={18} />
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* DETAIL MODAL */}
      {selectedBooking && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-in fade-in duration-300">
          <div className="bg-white rounded-2xl w-full max-w-2xl max-h-[90vh] overflow-hidden flex flex-col shadow-2xl animate-in zoom-in-95 duration-300">
            {/* Modal Header */}
            <div className="p-6 border-b border-gray-100 flex items-center justify-between bg-white sticky top-0 z-10">
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 bg-orange-100 text-orange-600 rounded-xl flex items-center justify-center">
                  <FileText size={24} />
                </div>
                <div>
                  <h2 className="text-xl font-black text-gray-900 tracking-tight">Booking Details</h2>
                  <p className="text-xs font-bold text-orange-500 uppercase tracking-widest">{selectedBooking.orderId || selectedBooking.id}</p>
                </div>
              </div>
              <button onClick={() => setSelectedBooking(null)} className="p-2 hover:bg-gray-100 rounded-full transition-colors text-gray-400">
                <X size={24} />
              </button>
            </div>

            <div className="p-6 overflow-y-auto space-y-8">
              {/* Status Section */}
              <div className="flex items-center justify-between p-4 bg-gray-50 rounded-xl border border-gray-100">
                <div className="flex items-center gap-3">
                  <div className={`w-3 h-3 rounded-full animate-pulse ${
                    selectedBooking.status === 'Completed' ? 'bg-emerald-500' :
                    selectedBooking.status === 'Cancelled' ? 'bg-rose-500' : 'bg-amber-500'
                  }`} />
                  <span className="text-sm font-black text-gray-900 uppercase tracking-tight">Current Progress: {selectedBooking.status}</span>
                </div>
                <span className="text-xs font-bold text-gray-400">{selectedBooking.createdAt?.seconds ? new Date(selectedBooking.createdAt.seconds * 1000).toLocaleString() : 'N/A'}</span>
              </div>

              {/* Service & People */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                <div className="space-y-4">
                  <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest border-l-2 border-orange-500 pl-2">Service Info</p>
                  <div className="space-y-3">
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 bg-indigo-50 text-indigo-600 rounded-lg flex items-center justify-center shrink-0">
                        <Briefcase size={20} />
                      </div>
                      <div>
                        <p className="text-xs font-bold text-gray-400">Service Category</p>
                        <p className="text-sm font-bold text-gray-900">{selectedBooking.category}</p>
                      </div>
                    </div>
                    <div>
                      <p className="text-sm font-bold text-gray-900 leading-tight">{selectedBooking.serviceName}</p>
                      <p className="text-xs text-gray-500 mt-1">Provided by <span className="font-bold text-indigo-600">{selectedBooking.providerName}</span></p>
                    </div>
                  </div>
                </div>

                <div className="space-y-4">
                  <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest border-l-2 border-blue-500 pl-2">Logistics</p>
                  <div className="space-y-3">
                    <div className="flex items-center gap-3">
                      <Calendar size={16} className="text-orange-500 shrink-0" />
                      <p className="text-sm font-bold text-gray-900">{selectedBooking.date} at {selectedBooking.time}</p>
                    </div>
                    <div className="flex items-start gap-3">
                      <MapPin size={16} className="text-orange-500 shrink-0 mt-1" />
                      <p className="text-sm font-medium text-gray-600 leading-relaxed italic">"{selectedBooking.address}"</p>
                    </div>
                  </div>
                </div>
              </div>

              {/* Financial Breakdown */}
              <div className="space-y-4">
                <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest border-l-2 border-emerald-500 pl-2">Financial Breakdown</p>
                <div className="bg-white border border-gray-100 rounded-xl overflow-hidden shadow-sm">
                  <div className="p-4 space-y-3">
                    <div className="flex justify-between items-center text-sm">
                      <span className="text-gray-500 font-medium">Base Service Price</span>
                      <span className="font-bold text-gray-900">RM {selectedBooking.basePrice?.toFixed(2)}</span>
                    </div>
                    {selectedBooking.selectedAddOns?.map((add, i) => (
                      <div key={i} className="flex justify-between items-center text-sm pl-4 border-l-2 border-gray-100">
                        <span className="text-gray-400 font-medium">+ {add.name}</span>
                        <span className="font-bold text-gray-700">RM {Number(add.price).toFixed(2)}</span>
                      </div>
                    ))}
                    <div className="pt-2 border-t border-dashed border-gray-100 flex justify-between items-center text-sm">
                      <span className="text-indigo-600 font-bold">Platform Commission (15%)</span>
                      <span className="font-bold text-indigo-600">- RM {(selectedBooking.chargeFee || (selectedBooking.totalPrice * 0.15)).toFixed(2)}</span>
                    </div>
                  </div>
                  <div className="p-4 bg-emerald-50/50 border-t border-emerald-100 flex justify-between items-center">
                    <div>
                      <p className="text-[10px] font-bold text-emerald-600 uppercase tracking-widest mb-0.5">Payment to Provider</p>
                      <div className="flex items-center gap-2">
                        <Wallet size={16} className="text-emerald-600" />
                        <span className="text-lg font-black text-emerald-700">RM {(selectedBooking.totalPrice - (selectedBooking.chargeFee || (selectedBooking.totalPrice * 0.15))).toFixed(2)}</span>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest mb-0.5">Customer Paid</p>
                      <span className="text-lg font-black text-gray-900">RM {selectedBooking.totalPrice?.toFixed(2)}</span>
                    </div>
                  </div>
                </div>
                <div className="flex items-center gap-2 px-4 py-2 bg-gray-50 rounded-lg border border-gray-100">
                  <CreditCard size={14} className="text-gray-400" />
                  <p className="text-[10px] font-bold text-gray-500 uppercase tracking-widest">Paid via {selectedBooking.paymentMethod?.toUpperCase() || 'Digital Payment'}</p>
                </div>
              </div>
            </div>

            {/* Modal Footer */}
            <div className="p-6 border-t border-gray-100 bg-gray-50 sticky bottom-0 z-10">
              <button 
                onClick={() => setSelectedBooking(null)}
                className="w-full py-3 bg-white border border-gray-200 rounded-xl font-black text-sm text-gray-700 hover:bg-gray-100 transition-all uppercase tracking-widest"
              >
                Close Details
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function VerificationPage({ requests }: { requests: VerificationRequest[] }) {
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [expandedId, setExpandedId] = useState<string | null>(null);

  const handleStatus = async (id: string, status: 'verified' | 'rejected') => {
    setActionLoading(id);
    try {
      await updateDoc(doc(db, 'providers', id), {
        verificationStatus: status
      });
    } catch (e: any) {
      alert(`Update failed: ${e.message}`);
    } finally {
      setActionLoading(null);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-lg font-bold text-gray-900 uppercase">Provider Verification</h1>
          <p className="text-gray-500 text-sm font-medium">Confirming identity for new professionals ({requests.length})</p>
        </div>
      </div>

      <div className="space-y-4">
        {requests.length === 0 ? (
          <div className="py-20 bg-white rounded-xl border border-dashed border-gray-200 flex flex-col items-center justify-center text-gray-400">
            <UserCheck size={48} className="mb-4 opacity-20" />
            <p className="font-medium">No pending verification requests</p>
            <p className="text-xs">All providers are currently up to date</p>
          </div>
        ) : requests.map((req) => (
          <div key={req.id} className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden transition-all duration-300">
            {/* COMPACT VIEW */}
            <div className="p-6 flex flex-col lg:flex-row items-start lg:items-center justify-between gap-4">
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 bg-orange-100 text-orange-600 rounded-lg flex items-center justify-center font-bold text-lg">
                  {req.name?.[0]?.toUpperCase()}
                </div>
                <div>
                  <h3 className="font-bold text-gray-900 leading-tight">{req.name}</h3>
                  <p className="text-xs text-gray-500">{req.email}</p>
                </div>
              </div>

              <div className="flex items-center gap-3 w-full lg:w-auto">
                <button
                  onClick={() => setExpandedId(expandedId === req.id ? null : req.id)}
                  className={`flex-1 lg:flex-none px-6 py-2.5 rounded-md font-bold text-sm transition-all flex items-center justify-center gap-2 ${expandedId === req.id
                      ? 'bg-gray-100 text-gray-700'
                      : 'bg-indigo-50 text-indigo-600 hover:bg-indigo-100'
                    }`}
                >
                  <Eye size={18} />
                  {expandedId === req.id ? 'Hide Details' : 'View Documents'}
                </button>

                <div className="flex gap-2">
                  <button
                    onClick={() => handleStatus(req.id, 'rejected')}
                    disabled={actionLoading === req.id}
                    className="p-2.5 text-red-500 hover:bg-red-50 rounded-md transition-colors border border-red-50"
                  >
                    <Ban size={20} />
                  </button>
                  <button
                    onClick={() => handleStatus(req.id, 'verified')}
                    disabled={actionLoading === req.id}
                    className="p-2.5 bg-emerald-500 text-white rounded-md shadow-lg shadow-emerald-100 hover:bg-emerald-600 transition-all"
                  >
                    {actionLoading === req.id ? (
                      <div className="animate-spin h-5 w-5 border-2 border-white border-t-transparent rounded-full" />
                    ) : (
                      <Check size={20} />
                    )}
                  </button>
                </div>
              </div>
            </div>

            {/* EXPANDED VIEW */}
            {expandedId === req.id && (
              <div className="p-6 border-t border-gray-50 bg-gray-50/30 animate-in fade-in slide-in-from-top-4 duration-300">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-8 mb-8">
                  <div className="space-y-4">
                    <div className="flex items-center justify-between">
                      <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Selfie Capture</p>
                    </div>
                    <div className="aspect-video bg-white rounded-lg overflow-hidden border border-gray-200 group relative shadow-md">
                      <img
                        src={req.selfieUrl}
                        alt="Selfie"
                        className="w-full h-full object-cover"
                        onClick={() => window.open(req.selfieUrl)}
                      />
                      <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center pointer-events-none">
                        <Search size={24} className="text-white" />
                      </div>
                    </div>
                  </div>

                  <div className="space-y-4">
                    <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Address Provided</p>
                    <div className="p-4 bg-white rounded-lg border border-gray-100 shadow-sm min-h-[100px] flex items-center">
                      <p className="text-sm text-gray-600 italic">"{req.address || 'No address provided by provider'}"</p>
                    </div>
                  </div>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
                  <div className="space-y-2">
                    <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest text-center">IC Front Side</p>
                    <div className="aspect-[3/2] bg-white rounded-lg overflow-hidden border border-gray-200 group relative shadow-md">
                      <img
                        src={req.icFrontUrl || req.icUrl}
                        alt="IC Front"
                        className="w-full h-full object-cover"
                        onClick={() => window.open(req.icFrontUrl || req.icUrl)}
                      />
                      <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center pointer-events-none">
                        <Search size={24} className="text-white" />
                      </div>
                    </div>
                  </div>

                  <div className="space-y-2">
                    <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest text-center">IC Back Side</p>
                    <div className="aspect-[3/2] bg-white rounded-lg overflow-hidden border border-gray-200 group relative shadow-md">
                      {req.icBackUrl ? (
                        <img
                          src={req.icBackUrl}
                          alt="IC Back"
                          className="w-full h-full object-cover"
                          onClick={() => window.open(req.icBackUrl)}
                        />
                      ) : (
                        <div className="w-full h-full flex flex-col items-center justify-center text-gray-300 gap-2">
                          <ShieldCheck size={32} className="opacity-10" />
                          <span className="text-[10px] italic">Not Provided</span>
                        </div>
                      )}
                      <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center pointer-events-none">
                        <Search size={24} className="text-white" />
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

function DashboardPage({ data, setActiveTab }: any) {
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

  const latestUsers = [...users]
    .sort((a: any, b: any) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0))
    .slice(0, 5);

  return (
    <div className="space-y-8">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-xl font-bold text-gray-900 tracking-tight">System Analytics</h1>
          <p className="text-gray-500 text-sm font-medium">Real-time ecosystem intelligence</p>
        </div>

        <PDFDownloadLink
          document={<ReportPDF users={users} services={services} reviews={reviews} bookings={bookings} />}
          fileName="GoServe_Platform_Report.pdf"
          className="bg-gray-900 text-white px-6 py-3 rounded-md font-bold text-sm shadow-xl hover:bg-gray-800 transition-all flex items-center gap-2"
        >
          {({ loading }) => (
            <>
              <Download size={18} />
              {loading ? 'Preparing Report...' : 'Generate PDF Report'}
            </>
          )}
        </PDFDownloadLink>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-6">
        <StatCard label="Total Revenue" value={`RM ${totalRevenue.toLocaleString(undefined, { minimumFractionDigits: 2 })}`} trend="+Actual" icon={<TrendingUp size={20} />} color="bg-emerald-500" />
        <StatCard label="Serviced Orders" value={completedBookings.toLocaleString()} trend="+Actual" icon={<Calendar size={20} />} color="bg-orange-500" />
        <StatCard label="Review Sentiment" value={avgRating} trend="Out of 5" icon={<Star size={20} />} color="bg-amber-500" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Main Charts Area */}
        <div className="lg:col-span-2 space-y-8">
          <div className="bg-white p-8 rounded-xl border border-gray-100 shadow-sm">
            <h3 className="font-bold text-gray-900 mb-8 flex items-center gap-2">
              <TrendingUp size={18} className="text-emerald-500" />
              Revenue Distribution
            </h3>
            <div className="h-80 w-full">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={chartData}>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9" />
                  <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{ fontSize: 12, fill: '#94a3b8' }} dy={10} />
                  <YAxis axisLine={false} tickLine={false} tick={{ fontSize: 12, fill: '#94a3b8' }} />
                  <Tooltip
                    contentStyle={{ borderRadius: '16px', border: 'none', boxShadow: '0 10px 15px -3px rgb(0 0 0 / 0.1)' }}
                  />
                  <Line type="monotone" dataKey="revenue" stroke="#10b981" strokeWidth={3} dot={{ r: 4, fill: '#10b981', strokeWidth: 2, stroke: '#fff' }} />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </div>

          <div className="bg-white p-8 rounded-xl border border-gray-100 shadow-sm">
            <h3 className="font-bold text-gray-900 mb-8 flex items-center gap-2">
              <Users size={18} className="text-blue-500" />
              Order Volume
            </h3>
            <div className="h-80 w-full">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={chartData}>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9" />
                  <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{ fontSize: 12, fill: '#94a3b8' }} dy={10} />
                  <YAxis axisLine={false} tickLine={false} tick={{ fontSize: 12, fill: '#94a3b8' }} />
                  <Tooltip
                    contentStyle={{ borderRadius: '16px', border: 'none', boxShadow: '0 10px 15px -3px rgb(0 0 0 / 0.1)' }}
                  />
                  <Bar dataKey="revenue" fill="#3b82f6" radius={[6, 6, 0, 0]} barSize={20} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>
        </div>

        {/* Right Sidebar: Total Community & Latest Members */}
        <div className="space-y-6">
          <div className="bg-white p-6 rounded-xl border border-gray-100 shadow-sm">
            <div className="flex items-center gap-4 mb-4">
              <div className="p-3 bg-blue-500 text-white rounded-lg shadow-lg">
                <Users size={20} />
              </div>
              <div>
                <p className="text-gray-500 text-xs font-medium uppercase tracking-wider">Total Community</p>
                <p className="text-2xl font-bold text-gray-900">{users.length.toLocaleString()}</p>
              </div>
            </div>
            <div className="pt-4 border-t border-gray-50">
              <div className="flex justify-between items-center mb-4">
                <h4 className="text-xs font-bold text-gray-400 uppercase tracking-widest">Latest Members</h4>
                <span className="px-2 py-0.5 bg-orange-50 text-orange-600 rounded-full text-[10px] font-black uppercase">New</span>
              </div>
              <div className="space-y-4">
                {latestUsers.map((u: any, idx: number) => (
                  <div key={u.id || idx} className="flex items-center gap-3 group">
                    <div className="w-8 h-8 rounded-lg bg-gray-50 flex items-center justify-center text-xs font-bold text-gray-400 group-hover:bg-orange-50 group-hover:text-orange-500 transition-colors">
                      {u.name?.[0]?.toUpperCase() || 'U'}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-bold text-gray-900 truncate group-hover:text-orange-500 transition-colors">{u.name || 'Anonymous'}</p>
                      <p className="text-[10px] text-gray-400 font-medium uppercase">{u.role || 'Member'}</p>
                    </div>
                    <span className="text-[10px] font-bold text-gray-300 italic whitespace-nowrap">
                      {u.createdAt ? new Date(u.createdAt.seconds * 1000).toLocaleDateString(undefined, { month: 'short', day: 'numeric' }) : '---'}
                    </span>
                  </div>
                ))}
              </div>
              <button 
                onClick={() => setActiveTab('users')}
                className="w-full mt-6 py-2.5 bg-gray-50 text-gray-500 rounded-lg text-[10px] font-black uppercase tracking-widest hover:bg-gray-100 hover:text-gray-700 transition-all border border-gray-100"
              >
                View All Community
              </button>
            </div>
          </div>

          <div className="bg-orange-500 p-6 rounded-xl shadow-xl shadow-orange-500/20 text-white relative overflow-hidden">
            <div className="relative z-10">
              <h3 className="font-bold text-lg mb-1">Growth Update</h3>
              <p className="text-white/80 text-xs leading-relaxed mb-4">You have {users.filter((u: any) => u.status === 'Active').length} active members contributing to the ecosystem.</p>
              <div className="flex items-center gap-2">
                <div className="flex -space-x-2">
                  {latestUsers.slice(0, 3).map((u: any, i: number) => (
                    <div key={i} className="w-6 h-6 rounded-full border-2 border-orange-500 bg-white flex items-center justify-center text-[8px] font-bold text-orange-500">
                      {u.name?.[0] || 'U'}
                    </div>
                  ))}
                </div>
                <span className="text-[10px] font-bold">+ {users.length - 3} others</span>
              </div>
            </div>
            <TrendingUp size={80} className="absolute -bottom-4 -right-4 text-white/10 rotate-12" />
          </div>
        </div>
      </div>
    </div>
  );
}

function StatCard({ label, value, trend, icon, color }: any) {
  return (
    <div className="bg-white p-6 rounded-xl border border-gray-100 shadow-sm">
      <div className="flex justify-between items-start mb-4">
        <div className={`p-3 rounded-lg ${color} text-white shadow-lg`}>
          {icon}
        </div>
        <span className="text-gray-400 text-[10px] font-bold px-2 py-1 bg-gray-50 rounded-full">{trend}</span>
      </div>
      <p className="text-gray-500 text-xs font-medium uppercase tracking-wider mb-1">{label}</p>
      <p className="text-2xl font-bold text-gray-900">{value}</p>
    </div>
  );
}

function UsersPage({ users, bookings, reviews, pendingApprovalsCount }: { users: AppUser[], bookings: any[], reviews: any[], pendingApprovalsCount: number }) {
  const [search, setSearch] = useState('');
  const [roleFilter, setRoleFilter] = useState<'All' | 'customer' | 'provider'>('All');
  const [statusFilter, setStatusFilter] = useState<'All' | 'Active' | 'Inactive' | 'Suspended'>('All');
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [activeMenu, setActiveMenu] = useState<string | null>(null);
  const [selectedUser, setSelectedUser] = useState<any | null>(null);

  const handleAction = async (uid: string, role: string, action: 'delete' | 'suspend' | 'activate') => {
    const roleMapping = role === 'Professional' ? 'Professional' : 'Seeker';
    const actionText = action === 'delete' ? 'DELETE' : action === 'suspend' ? 'SUSPEND' : 'ACTIVATE';
    
    if (!window.confirm(`⚠️ CRITICAL ACTION\n\nAre you sure you want to ${actionText} this account?\nThis action will take effect immediately.`)) return;

    setActionLoading(uid);
    setActiveMenu(null);
    try {
      const functions = getFunctions();
      if (action === 'delete') {
        const deleteFn = httpsCallable(functions, 'deleteUser');
        await deleteFn({ uid, role: roleMapping });
      } else {
        const toggleFn = httpsCallable(functions, 'toggleUserStatus');
        await toggleFn({ uid, role: roleMapping, status: action === 'suspend' ? 'Suspended' : 'Active' });
      }
    } catch (e: any) {
      console.error('Action Error:', e);
      alert(`Action failed: ${e.message}`);
    } finally {
      setActionLoading(null);
    }
  };

  const isInactive = (u: any) => {
    if (u.status === 'Suspended') return false;
    if (u.isOnline) return false;

    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    // If they have lastSeen, check it
    if (u.lastSeen) {
      const lastSeenDate = new Date(u.lastSeen.seconds * 1000);
      return lastSeenDate < thirtyDaysAgo;
    }

    // Fallback: If no lastSeen, check if they joined more than 30 days ago
    if (u.createdAt) {
      const joinDate = new Date(u.createdAt.seconds * 1000);
      return joinDate < thirtyDaysAgo;
    }

    return true; 
  };

  const getStatus = (u: any) => {
    if (u.status === 'Suspended') return 'Suspended';
    return isInactive(u) ? 'Inactive' : 'Active';
  };

  const filteredUsers = users
    .filter((u: any) => {
      const matchesSearch = !search || 
                            u.name?.toLowerCase().includes(search.toLowerCase()) || 
                            u.email?.toLowerCase().includes(search.toLowerCase()) ||
                            u.customId?.toLowerCase().includes(search.toLowerCase());
      const matchesRole = roleFilter === 'All' || u.role?.toLowerCase() === roleFilter.toLowerCase();
      const matchesStatus = statusFilter === 'All' || getStatus(u) === statusFilter;
      return matchesSearch && matchesRole && matchesStatus;
    })
    .sort((a: any, b: any) => {
      const dateA = a.createdAt?.seconds || 0;
      const dateB = b.createdAt?.seconds || 0;
      return dateB - dateA;
    });

  const [currentPage, setCurrentPage] = useState(1);
  const pageSize = 5; // Showing 5 per page for better layout
  const totalPages = Math.ceil(filteredUsers.length / pageSize);
  const paginatedUsers = filteredUsers.slice((currentPage - 1) * pageSize, currentPage * pageSize);

  const getPageNumbers = () => {
    const pages = [];
    if (totalPages <= 5) {
      for (let i = 1; i <= totalPages; i++) pages.push(i);
    } else {
      if (currentPage <= 3) {
        pages.push(1, 2, 3, '...', totalPages);
      } else if (currentPage >= totalPages - 2) {
        pages.push(1, '...', totalPages - 2, totalPages - 1, totalPages);
      } else {
        pages.push(1, '...', currentPage, '...', totalPages);
      }
    }
    return pages;
  };

  // Reset page when filters change
  useEffect(() => {
    setCurrentPage(1);
  }, [search, roleFilter, statusFilter]);

  // Growth Metrics (Derived from real data)
  const now = new Date();
  const last30Days = new Date(now.setDate(now.getDate() - 30));
  const newRegistrationsCount = users.filter(u => u.createdAt && new Date(u.createdAt.seconds * 1000) > last30Days).length;
  const providerOnboardingCount = users.filter(u => u.role === 'Professional' && u.createdAt && new Date(u.createdAt.seconds * 1000) > last30Days).length;



  const exportToCSV = () => {
    const headers = ['User ID', 'Name', 'Email', 'Role', 'Status', 'Joined Date'];
    const rows = filteredUsers.map(u => [
      `"${u.customId || 'N/A'}"`,
      `"${u.name || 'Anonymous'}"`,
      `"${u.email || 'N/A'}"`,
      u.role === 'Professional' ? 'Provider' : 'User',
      getStatus(u),
      u.createdAt ? new Date(u.createdAt.seconds * 1000).toLocaleDateString() : 'N/A'
    ]);
    
    const csvContent = [headers.join(','), ...rows.map(e => e.join(','))].join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = `GoServe_Members_${new Date().toISOString().split('T')[0]}.csv`;
    link.click();
  };

  return (
    <div className="space-y-8 pb-10">
      {/* HEADER SECTION */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-6">
        <div className="space-y-1">
          <h1 className="text-xl font-bold text-gray-900 tracking-tight">User Management</h1>
          <p className="text-gray-500 text-sm max-w-lg leading-relaxed">
            Manage all system users and service providers, monitor their status, and control access permissions.
          </p>
        </div>
        <div className="flex items-center gap-3 w-full md:w-auto">

          <button 
            onClick={exportToCSV}
            className="flex-1 md:flex-none flex items-center justify-center gap-2 px-4 py-2.5 bg-orange-500 text-white rounded-lg text-sm font-bold hover:bg-orange-600 transition-all shadow-sm shadow-orange-100"
          >
            <Download size={18} />
            Export CSV
          </button>
        </div>
      </div>

      {/* FILTER BAR */}
      <div className="bg-white p-4 rounded-xl border border-gray-100 shadow-sm flex items-center justify-between gap-4">
        <div className="flex items-center gap-4 flex-1">
          <div className="relative flex-1 max-w-md">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
            <input
              type="text"
              placeholder="Search name, email, or ID..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full pl-10 pr-4 py-2 bg-gray-50 border border-gray-200 rounded-lg text-sm font-medium focus:outline-none focus:ring-2 focus:ring-orange-500/20 transition-all"
            />
          </div>

          <div className="h-6 w-[1px] bg-gray-200 mx-2" />

          <div className="relative">
            <select 
              value={roleFilter}
              onChange={(e) => setRoleFilter(e.target.value as any)}
              className="appearance-none pl-4 pr-10 py-2 bg-white border border-gray-200 rounded-lg text-sm font-semibold text-gray-700 focus:outline-none focus:ring-2 focus:ring-orange-500/20 cursor-pointer"
            >
              <option value="All">All Roles</option>
              <option value="customer">Customers</option>
              <option value="provider">Providers</option>
            </select>
            <ChevronRight size={14} className="absolute right-3 top-1/2 -translate-y-1/2 rotate-90 text-gray-400 pointer-events-none" />
          </div>

          <div className="relative">
            <select 
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value as any)}
              className="appearance-none pl-4 pr-10 py-2 bg-white border border-gray-200 rounded-lg text-sm font-semibold text-gray-700 focus:outline-none focus:ring-2 focus:ring-orange-500/20 cursor-pointer"
            >
              <option value="All">All Statuses</option>
              <option value="Active">Active</option>
              <option value="Inactive">Inactive</option>
              <option value="Suspended">Suspended</option>
            </select>
            <ChevronRight size={14} className="absolute right-3 top-1/2 -translate-y-1/2 rotate-90 text-gray-400 pointer-events-none" />
          </div>

          <div className="relative">
            <div className="flex items-center gap-2 pl-4 pr-4 py-2 bg-white border border-gray-200 rounded-lg text-sm font-semibold text-gray-700">
              <Calendar size={16} className="text-gray-400" />
              <span>Last 30 Days</span>
            </div>
          </div>
        </div>

        <button 
          onClick={() => {
            setSearch('');
            setRoleFilter('All');
            setStatusFilter('All');
          }}
          className="flex items-center gap-2 text-gray-400 hover:text-gray-600 font-bold text-sm transition-colors"
        >
          <RotateCcw size={16} />
          Reset
        </button>
      </div>

      {/* TABLE SECTION */}
      <div className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left">
            <thead>
              <tr className="border-b border-gray-100">
                <th className="px-8 py-5 text-[11px] font-bold uppercase text-gray-400 tracking-wider">Name & Contact</th>
                <th className="px-6 py-5 text-[11px] font-bold uppercase text-gray-400 tracking-wider">User ID</th>
                <th className="px-6 py-5 text-[11px] font-bold uppercase text-gray-400 tracking-wider">Role</th>
                <th className="px-6 py-5 text-[11px] font-bold uppercase text-gray-400 tracking-wider">Status</th>
                <th className="px-6 py-5 text-[11px] font-bold uppercase text-gray-400 tracking-wider">Joined</th>
                <th className="px-8 py-5 text-[11px] font-bold uppercase text-gray-400 tracking-wider text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {filteredUsers.length === 0 ? (
                <tr><td colSpan={6} className="p-20 text-center text-gray-400 font-medium">No members found matching your criteria.</td></tr>
              ) : (
                <>
                  {paginatedUsers.map((u: any) => (
                    <tr key={u.id} className="group hover:bg-gray-50/50 transition-colors">
                      <td className="px-8 py-5">
                        <div className="flex items-center gap-4">
                          <div className="relative">
                            <div className="w-11 h-11 rounded-full bg-gray-100 border-2 border-white shadow-sm overflow-hidden">
                              {u.profileUrl ? (
                                <img src={u.profileUrl} alt={u.name} className="w-full h-full object-cover" />
                              ) : (
                                <div className="w-full h-full flex items-center justify-center font-bold text-gray-400">
                                  {u.name?.[0]?.toUpperCase() || '?'}
                                </div>
                              )}
                            </div>
                          </div>
                          <div>
                            <div className="flex items-center gap-1.5 mb-1">
                              <p className="font-bold text-[15px] text-gray-900 leading-none">{u.name || 'Anonymous Member'}</p>
                              {u.verificationStatus === 'verified' && (
                                <ShieldCheck size={14} className="text-blue-500" />
                              )}
                            </div>
                            <p className="text-sm text-gray-500">{u.email}</p>
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-5 text-sm font-semibold text-gray-600">
                        {u.customId || "Pending"}
                      </td>
                      <td className="px-6 py-5">
                        <span className={`px-2.5 py-1 rounded-md text-[10px] font-bold uppercase tracking-wider border ${
                          u.role?.toLowerCase() === 'provider' 
                            ? 'bg-indigo-50/50 text-indigo-600 border-indigo-100' 
                            : 'bg-orange-50/30 text-orange-600 border-orange-100'
                        }`}>
                          {u.role || 'User'}
                        </span>
                      </td>
                      <td className="px-6 py-5">
                        <div className="flex items-center gap-2">
                          <div className={`w-1.5 h-1.5 rounded-full ${
                            u.status === 'Suspended' ? 'bg-rose-500' : 
                            isInactive(u) ? 'bg-gray-400' : 'bg-emerald-500'
                          }`} />
                          <span className={`text-sm font-bold ${
                            u.status === 'Suspended' ? 'text-rose-600' : 
                            isInactive(u) ? 'text-gray-500' : 'text-emerald-600'
                          }`}>
                            {getStatus(u)}
                          </span>
                        </div>
                      </td>
                      <td className="px-6 py-5 text-sm font-semibold text-gray-600">
                        {u.createdAt ? new Date(u.createdAt.seconds * 1000).toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' }) : '---'}
                      </td>
                      <td className="px-8 py-5 text-right relative">
                        <div className="flex items-center justify-end gap-2 text-gray-400">
                          <button onClick={() => setSelectedUser(u)} className="p-2 hover:bg-gray-50 rounded-lg transition-colors hover:text-gray-600">
                            <FileText size={18} />
                          </button>
                          
                          <div className="relative">
                            <button 
                              onClick={() => setActiveMenu(activeMenu === u.id ? null : u.id)}
                              className={`p-2 rounded-lg transition-colors hover:text-gray-600 ${activeMenu === u.id ? 'bg-gray-100 text-gray-900' : 'hover:bg-gray-50'}`}
                            >
                              <MoreVertical size={18} />
                            </button>

                            {activeMenu === u.id && (
                              <>
                                <div className="fixed inset-0 z-10" onClick={() => setActiveMenu(null)} />
                                <div className="absolute right-0 mt-2 w-56 bg-white rounded-xl shadow-2xl border border-gray-100 py-2 z-20 animate-in fade-in zoom-in-95 duration-150 origin-top-right">
                                  <div className="px-4 py-2 mb-1 border-b border-gray-50">
                                    <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Account Actions</p>
                                  </div>
                                  <button
                                    onClick={() => handleAction(u.id, u.role, u.status === 'Suspended' ? 'activate' : 'suspend')}
                                    className="w-full px-4 py-2.5 text-left text-sm font-bold text-gray-700 hover:bg-gray-50 flex items-center gap-3 transition-colors"
                                  >
                                    {u.status === 'Suspended' ? <Check size={18} className="text-emerald-500" /> : <Ban size={18} className="text-amber-500" />}
                                    {u.status === 'Suspended' ? 'Activate Account' : 'Suspend Account'}
                                  </button>
                                  <button
                                    onClick={() => handleAction(u.id, u.role, 'delete')}
                                    className="w-full px-4 py-2.5 text-left text-sm font-bold text-red-600 hover:bg-red-50 flex items-center gap-3 transition-colors"
                                  >
                                    <Trash2 size={18} />
                                    Delete Account
                                  </button>
                                </div>
                              </>
                            )}
                          </div>
                        </div>
                        {actionLoading === u.id && (
                          <div className="absolute inset-0 bg-white/60 backdrop-blur-[1px] flex items-center justify-center z-30">
                            <div className="animate-spin h-5 w-5 border-2 border-orange-500 border-t-transparent rounded-full" />
                          </div>
                        )}
                      </td>
                    </tr>
                  ))}
                  
                  {/* EMPTY ROWS TO MAINTAIN HEIGHT */}
                  {Array.from({ length: pageSize - paginatedUsers.length }).map((_, index) => (
                    <tr key={`empty-${index}`} className="h-[85px] border-b border-gray-50 last:border-0">
                      <td colSpan={5} className="px-6 py-5" />
                    </tr>
                  ))}
                </>
              )}
            </tbody>
          </table>
        </div>

        {/* PAGINATION */}
        <div className="p-6 border-t border-gray-50 flex items-center justify-between">
          <p className="text-sm font-semibold text-gray-500">
            Showing <span className="text-gray-900 font-bold">{filteredUsers.length === 0 ? 0 : (currentPage - 1) * pageSize + 1}-{Math.min(currentPage * pageSize, filteredUsers.length)}</span> of <span className="text-gray-900 font-bold">{filteredUsers.length.toLocaleString()}</span> members
          </p>
          <div className="flex items-center gap-1.5">
            <button 
              onClick={() => setCurrentPage(prev => Math.max(1, prev - 1))}
              disabled={currentPage === 1}
              className={`p-2 border border-gray-100 rounded-lg transition-colors ${currentPage === 1 ? 'text-gray-200 cursor-not-allowed' : 'text-gray-500 hover:bg-gray-50'}`}
            >
              <ChevronLeft size={18} />
            </button>
            
            {getPageNumbers().map((p, i) => (
              p === '...' ? (
                <span key={`dots-${i}`} className="text-gray-400 px-1">...</span>
              ) : (
                <button
                  key={p}
                  onClick={() => setCurrentPage(p as number)}
                  className={`w-9 h-9 flex items-center justify-center rounded-lg font-bold text-sm transition-all ${
                    currentPage === p 
                      ? 'bg-orange-500 text-white shadow-md' 
                      : 'hover:bg-gray-50 text-gray-600'
                  }`}
                >
                  {p}
                </button>
              )
            ))}

            <button 
              onClick={() => setCurrentPage(prev => Math.min(totalPages, prev + 1))}
              disabled={currentPage === totalPages || totalPages === 0}
              className={`p-2 border border-gray-100 rounded-lg transition-colors ${currentPage === totalPages || totalPages === 0 ? 'text-gray-200 cursor-not-allowed' : 'text-gray-500 hover:bg-gray-50'}`}
            >
              <ChevronRight size={18} />
            </button>
          </div>
        </div>
      </div>

      {/* BOTTOM SECTION */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 items-stretch">
        <div className="lg:col-span-2 bg-white p-8 rounded-xl border border-gray-100 shadow-sm flex flex-col justify-between">
          <div>
            <h3 className="text-lg font-bold text-gray-900 mb-1">Growth Overview</h3>
            <p className="text-gray-400 text-xs font-medium mb-12">Performance metrics for the current billing cycle.</p>
          </div>
          
          <div className="grid grid-cols-3 gap-4">
            <div>
              <p className="text-3xl font-extrabold text-orange-500 mb-1">{newRegistrationsCount.toLocaleString()}</p>
              <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">New Registrations</p>
            </div>
            <div>
              <p className="text-3xl font-extrabold text-gray-900 mb-1">{providerOnboardingCount.toLocaleString()}</p>
              <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Provider Onboarding</p>
            </div>
            <div>
              <p className="text-3xl font-extrabold text-emerald-500 mb-1">+12%</p>
              <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Monthly Growth</p>
            </div>
          </div>
        </div>

        <div className="bg-orange-500 p-8 rounded-xl text-white shadow-xl shadow-orange-100 flex flex-col justify-between relative overflow-hidden">
          <div className="absolute top-0 right-0 p-8 opacity-10">
            <ShieldCheck size={120} className="translate-x-1/4 -translate-y-1/4" />
          </div>
          
          <div className="relative z-10">
            <div className="flex items-center justify-between mb-2">
              <h3 className="text-lg font-bold">Pending Approvals</h3>
              <ShieldCheck size={20} />
            </div>
            <p className="text-orange-100 text-xs font-medium mb-10">Verification queue is active</p>
          </div>

          <div className="relative z-10 space-y-6">
            <div className="flex items-baseline gap-2">
              <span className="text-5xl font-extrabold">{pendingApprovalsCount}</span>
              <span className="text-sm font-bold opacity-80">Providers</span>
            </div>
            <button className="w-full py-3 bg-white text-orange-500 rounded-lg font-bold text-sm hover:bg-orange-50 transition-all shadow-lg">
              Start Review
            </button>
          </div>
        </div>
      </div>
      {/* USER PROFILE MODAL */}
      {selectedUser && (
        <UserProfilePage 
          user={selectedUser} 
          bookings={bookings} 
          reviews={reviews}
          onClose={() => setSelectedUser(null)} 
          getStatus={getStatus}
        />
      )}
    </div>
  );
}

function UserProfilePage({ user, bookings, reviews, onClose, getStatus }: any) {
  // Calculate user-specific stats
  const userBookings = bookings.filter((b: any) => 
    b.customerId === user.id || b.providerId === user.id
  );
  const completedBookings = userBookings.filter((b: any) => b.status === 'completed');
  
  const userReviews = reviews.filter((r: any) => r.providerId === user.id);
  const avgRating = userReviews.length > 0 
    ? (userReviews.reduce((sum: number, r: any) => sum + (r.rating || 0), 0) / userReviews.length) 
    : (user.rating || 0);
  
  const totalEarnings = completedBookings
    .filter((b: any) => b.providerId === user.id)
    .reduce((sum: number, b: any) => sum + (parseFloat(b.totalPrice || b.price || '0')), 0);

  const isProvider = user.role?.toLowerCase() === 'provider';

  // Sort bookings by date for recent activity
  const recentBookings = [...userBookings]
    .sort((a: any, b: any) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0))
    .slice(0, 5);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm" onClick={onClose}>
      <div 
        className="relative bg-white w-full max-w-3xl max-h-[90vh] rounded-2xl overflow-hidden shadow-2xl animate-in zoom-in-95 duration-300 overflow-y-auto"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header Banner */}
        <div className={`relative h-32 ${isProvider ? 'bg-gradient-to-r from-indigo-500 to-indigo-600' : 'bg-gradient-to-r from-orange-400 to-orange-500'}`}>
          <button 
            onClick={onClose} 
            className="absolute top-4 right-4 p-2 bg-white/20 hover:bg-white/30 rounded-lg text-white transition-all"
          >
            <X size={18} />
          </button>
          <div className="absolute top-4 left-4 flex items-center gap-2">
            <button onClick={onClose} className="p-2 bg-white/20 hover:bg-white/30 rounded-lg text-white transition-all">
              <ArrowLeft size={18} />
            </button>
            <span className="text-white/80 text-sm font-semibold">User Profile</span>
          </div>
        </div>

        {/* Profile Info */}
        <div className="px-8 -mt-12 relative z-10">
          <div className="flex items-end gap-5">
            <div className="w-24 h-24 rounded-2xl bg-white border-4 border-white shadow-lg overflow-hidden shrink-0">
              {user.profileUrl ? (
                <img src={user.profileUrl} alt={user.name} className="w-full h-full object-cover" />
              ) : (
                <div className={`w-full h-full flex items-center justify-center text-2xl font-bold text-white ${isProvider ? 'bg-indigo-400' : 'bg-orange-400'}`}>
                  {user.name?.[0]?.toUpperCase() || '?'}
                </div>
              )}
            </div>
            <div className="pb-1 flex-1">
              <div className="flex items-center gap-3 mb-1">
                <h2 className="text-xl font-bold text-gray-900">{user.name || 'Anonymous'}</h2>
                {user.verificationStatus === 'verified' && (
                  <ShieldCheck size={16} className="text-blue-500" />
                )}
                <span className={`px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider border ${
                  isProvider 
                    ? 'bg-indigo-50/50 text-indigo-600 border-indigo-100' 
                    : 'bg-orange-50/30 text-orange-600 border-orange-100'
                }`}>
                  {user.role || 'customer'}
                </span>
              </div>
              <p className="text-sm text-gray-500 font-medium">{user.customId || 'No ID'} · Joined {user.createdAt ? new Date(user.createdAt.seconds * 1000).toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' }) : '---'}</p>
            </div>
            <div className="pb-1">
              <div className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-bold ${
                getStatus(user) === 'Active' ? 'bg-emerald-50 text-emerald-600' :
                getStatus(user) === 'Suspended' ? 'bg-rose-50 text-rose-600' :
                'bg-gray-50 text-gray-500'
              }`}>
                <div className={`w-1.5 h-1.5 rounded-full ${
                  getStatus(user) === 'Active' ? 'bg-emerald-500' :
                  getStatus(user) === 'Suspended' ? 'bg-rose-500' :
                  'bg-gray-400'
                }`} />
                {getStatus(user)}
              </div>
            </div>
          </div>
        </div>

        {/* Contact Details */}
        <div className="px-8 mt-6">
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div className="flex items-center gap-3 p-3 bg-gray-50 rounded-xl">
              <div className="p-2 bg-white rounded-lg shadow-sm">
                <Mail size={16} className="text-gray-400" />
              </div>
              <div className="min-w-0">
                <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Email</p>
                <p className="text-sm font-semibold text-gray-700 truncate">{user.email || '---'}</p>
              </div>
            </div>
            <div className="flex items-center gap-3 p-3 bg-gray-50 rounded-xl">
              <div className="p-2 bg-white rounded-lg shadow-sm">
                <Phone size={16} className="text-gray-400" />
              </div>
              <div className="min-w-0">
                <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Phone</p>
                <p className="text-sm font-semibold text-gray-700 truncate">{user.phone || '---'}</p>
              </div>
            </div>
            <div className="flex items-center gap-3 p-3 bg-gray-50 rounded-xl">
              <div className="p-2 bg-white rounded-lg shadow-sm">
                <MapPin size={16} className="text-gray-400" />
              </div>
              <div className="min-w-0">
                <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Address</p>
                <p className="text-sm font-semibold text-gray-700 truncate">{user.address || '---'}</p>
              </div>
            </div>
          </div>
        </div>

        {/* Stats Cards */}
        <div className="px-8 mt-6">
          <div className={`grid ${isProvider ? 'grid-cols-3' : 'grid-cols-2'} gap-4`}>
            <div className="bg-white border border-gray-100 rounded-xl p-5 shadow-sm">
              <div className="flex items-center gap-3 mb-3">
                <div className="p-2 bg-blue-50 rounded-lg">
                  <Calendar size={16} className="text-blue-500" />
                </div>
                <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Total Bookings</p>
              </div>
              <p className="text-2xl font-bold text-gray-900">{userBookings.length}</p>
              <p className="text-xs text-gray-400 mt-1">{completedBookings.length} completed</p>
            </div>
            <div className="bg-white border border-gray-100 rounded-xl p-5 shadow-sm">
              <div className="flex items-center gap-3 mb-3">
                <div className="p-2 bg-amber-50 rounded-lg">
                  <Star size={16} className="text-amber-500" />
                </div>
                <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Average Rating</p>
              </div>
              <p className="text-2xl font-bold text-gray-900">{avgRating.toFixed(1)}</p>
              <p className="text-xs text-gray-400 mt-1">{userReviews.length} reviews</p>
            </div>
            {isProvider && (
              <div className="bg-white border border-gray-100 rounded-xl p-5 shadow-sm">
                <div className="flex items-center gap-3 mb-3">
                  <div className="p-2 bg-emerald-50 rounded-lg">
                    <DollarSign size={16} className="text-emerald-500" />
                  </div>
                  <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Total Earnings</p>
                </div>
                <p className="text-2xl font-bold text-gray-900">RM {totalEarnings.toFixed(2)}</p>
                <p className="text-xs text-gray-400 mt-1">From {completedBookings.filter((b: any) => b.providerId === user.id).length} orders</p>
              </div>
            )}
          </div>
        </div>

        {/* Recent Activity */}
        <div className="px-8 mt-6 pb-8">
          <h3 className="text-sm font-bold text-gray-900 mb-4 flex items-center gap-2">
            <Clock size={14} className="text-gray-400" />
            Recent Activity
          </h3>
          {recentBookings.length === 0 ? (
            <div className="text-center py-8 text-gray-400">
              <Calendar size={28} className="mx-auto mb-2 opacity-50" />
              <p className="text-sm font-medium">No activity yet</p>
            </div>
          ) : (
            <div className="space-y-3">
              {recentBookings.map((b: any) => (
                <div key={b.id} className="flex items-center gap-4 p-3 bg-gray-50 rounded-xl hover:bg-gray-100/80 transition-colors">
                  <div className={`p-2 rounded-lg shrink-0 ${
                    b.status === 'completed' ? 'bg-emerald-50' :
                    b.status === 'cancelled' ? 'bg-rose-50' :
                    'bg-blue-50'
                  }`}>
                    <Briefcase size={14} className={
                      b.status === 'completed' ? 'text-emerald-500' :
                      b.status === 'cancelled' ? 'text-rose-500' :
                      'text-blue-500'
                    } />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-gray-800 truncate">{b.serviceName || b.serviceTitle || 'Service Booking'}</p>
                    <p className="text-xs text-gray-400">
                      {b.createdAt ? new Date(b.createdAt.seconds * 1000).toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' }) : '---'}
                    </p>
                  </div>
                  <span className={`px-2 py-1 rounded text-[10px] font-bold uppercase tracking-wider ${
                    b.status === 'completed' ? 'bg-emerald-50 text-emerald-600' :
                    b.status === 'cancelled' ? 'bg-rose-50 text-rose-600' :
                    b.status === 'pending' ? 'bg-amber-50 text-amber-600' :
                    'bg-blue-50 text-blue-600'
                  }`}>
                    {b.status || 'pending'}
                  </span>
                  {b.totalPrice && (
                    <span className="text-sm font-bold text-gray-700">RM {parseFloat(b.totalPrice || b.price || '0').toFixed(2)}</span>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
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
        <h1 className="text-lg font-bold text-gray-900 uppercase">Review Board</h1>
        <p className="text-gray-500 text-sm font-medium">Moderating Marketplace Veracity</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {reviews.length === 0 ? (
          <div className="col-span-full p-20 text-center text-gray-400">No Reviews to moderate.</div>
        ) : reviews.map((r: any) => (
          <div key={r.id} className="bg-white p-6 rounded-xl border border-gray-100 shadow-sm">
            <div className="flex justify-between items-start mb-4">
              <div className="flex items-center gap-1">
                {[...Array(5)].map((_, i) => (
                  <Star key={i} size={14} fill={i < r.rating ? "#f59e0b" : "#e2e8f0"} className={i < r.rating ? "text-amber-500" : "text-gray-200"} />
                ))}
              </div>
              <span className={`text-[10px] font-bold uppercase px-2 py-1 rounded ${r.status === 'Approved' ? 'bg-emerald-50 text-emerald-600' : r.status === 'Rejected' ? 'bg-red-50 text-red-600' : 'bg-orange-50 text-orange-600'
                }`}>
                {r.status || 'Pending'}
              </span>
            </div>
            <p className="font-bold text-gray-900">{r.serviceName || 'Service'}</p>
            <p className="text-xs text-gray-600 mb-6 italic">"{r.comment}"</p>
            <div className="flex gap-2">
              <button onClick={() => handleStatus(r.id, 'Approved')} className="flex-1 py-2 bg-emerald-500 text-white rounded-md font-bold text-xs">Approve</button>
              <button onClick={() => handleStatus(r.id, 'Rejected')} className="flex-1 py-2 border border-gray-100 text-red-500 rounded-md font-bold text-xs">Reject</button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function ServicesPage({ services, users, bookings, reviews }: { services: Service[], users: AppUser[], bookings: any[], reviews: any[] }) {
  const [selectedService, setSelectedService] = useState<Service | null>(null);
  const [search, setSearch] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('All');
  const [layout, setLayout] = useState<'grid' | 'list'>('grid');
  const [isMigrating, setIsMigrating] = useState(false);

  const migrateServiceIds = async () => {
    if (!window.confirm("This will assign SVCXXX IDs to all services that don't have one. Continue?")) return;
    
    setIsMigrating(true);
    try {
      // Use existing services from props to find max ID
      let maxNum = 0;
      services.forEach(s => {
        if (s.customId && s.customId.startsWith('SVC')) {
          const numPart = s.customId.substring(3);
          const num = parseInt(numPart);
          if (!isNaN(num) && num > maxNum) maxNum = num;
        }
      });

      // Find services without customId
      const toFix = services.filter(s => !s.customId);
      
      if (toFix.length === 0) {
        alert("All services already have custom IDs.");
        return;
      }

      const batch = writeBatch(db);
      toFix.forEach((s) => {
        maxNum++;
        const newId = `SVC${maxNum.toString().padStart(3, '0')}`;
        const ref = doc(db, 'services', s.id);
        batch.update(ref, { customId: newId });
      });

      await batch.commit();
      alert(`Successfully migrated ${toFix.length} services.`);
    } catch (e: any) {
      console.error(e);
      alert(`Migration failed: ${e.message}`);
    } finally {
      setIsMigrating(false);
    }
  };

  const getServiceStats = (serviceId: string) => {
    const serviceBookings = bookings.filter(b => b.serviceId === serviceId);
    const serviceReviews = reviews.filter(r => r.serviceId === serviceId);
    const avgRating = serviceReviews.length > 0 
      ? serviceReviews.reduce((sum, r) => sum + (r.rating || 0), 0) / serviceReviews.length
      : 0;
    
    return {
      totalBookings: serviceBookings.length,
      avgRating: avgRating.toFixed(1),
      reviewCount: serviceReviews.length
    };
  };
  const categories = [
    'Home Services', 
    'Electrical & Wiring', 
    'Automotive', 
    'Moving', 
    'Health', 
    'Pet Services', 
    'Safety', 
    'Event',
    'Others'
  ];

  const toggleStatus = async (id: string, current: boolean) => {
    try {
      await updateDoc(doc(db, 'services', id), {
        isActive: !current
      });
    } catch (e) {
      console.error(e);
    }
  };

  const filteredServices = services.filter(s => {
    const provider = users.find(u => u.id === s.providerId);
    const matchesSearch = !search || 
      s.title?.toLowerCase().includes(search.toLowerCase()) ||
      s.description?.toLowerCase().includes(search.toLowerCase()) ||
      s.providerName?.toLowerCase().includes(search.toLowerCase()) ||
      s.providerId?.toLowerCase().includes(search.toLowerCase()) ||
      provider?.customId?.toLowerCase().includes(search.toLowerCase()) ||
      s.id?.toLowerCase().includes(search.toLowerCase()) ||
      s.customId?.toLowerCase().includes(search.toLowerCase());
    
    const matchesCategory = categoryFilter === 'All' || (s.category && s.category.startsWith(categoryFilter));
    
    return matchesSearch && matchesCategory;
  });

  const getCategoryColor = (category?: string) => {
    const mainCat = category?.split('>')[0].trim().toLowerCase() || '';
    
    if (mainCat.includes('cleaning') || mainCat.includes('home')) return 'bg-blue-50 text-blue-600 border-blue-100';
    if (mainCat.includes('plumbing')) return 'bg-cyan-50 text-cyan-600 border-cyan-100';
    if (mainCat.includes('electrical')) return 'bg-amber-50 text-amber-600 border-amber-100';
    if (mainCat.includes('automotive')) return 'bg-rose-50 text-rose-600 border-rose-100';
    if (mainCat.includes('moving')) return 'bg-purple-50 text-purple-600 border-purple-100';
    if (mainCat.includes('health')) return 'bg-emerald-50 text-emerald-600 border-emerald-100';
    if (mainCat.includes('pet')) return 'bg-pink-50 text-pink-600 border-pink-100';
    if (mainCat.includes('safety')) return 'bg-slate-50 text-slate-600 border-slate-100';
    if (mainCat.includes('event')) return 'bg-indigo-50 text-indigo-600 border-indigo-100';
    
    return 'bg-gray-50 text-gray-600 border-gray-100';
  };

  const exportToCSV = () => {
    const headers = [
      "Service ID",
      "Service Title",
      "Provider Name",
      "Provider ID",
      "Category",
      "Price (RM)",
      "Total Bookings",
      "Average Rating",
      "Status"
    ];

    const rows = filteredServices.map(s => {
      const stats = getServiceStats(s.id);
      const provider = users.find(u => u.id === s.providerId);
      return [
        s.customId || s.id,
        s.title || "Untitled",
        s.providerName || "Unknown",
        provider?.customId || s.providerId || "N/A",
        s.category || "N/A",
        Number(s.price).toFixed(2),
        stats.totalBookings,
        stats.avgRating,
        (s.isActive ?? true) ? "Active" : "Hidden"
      ];
    });

    const csvContent = [
      headers.join(","),
      ...rows.map(row => row.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(","))
    ].join("\n");

    const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.setAttribute("href", url);
    link.setAttribute("download", `GoServe_Services_${new Date().toISOString().split('T')[0]}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col xl:flex-row justify-between items-start xl:items-center gap-6">
        <div>
          <h1 className="text-lg font-bold text-gray-900 uppercase tracking-tight">Marketplace Services</h1>
          <div className="flex items-center gap-3">
            <p className="text-gray-500 text-sm font-medium">Monitoring active offerings ({filteredServices.length})</p>
            <button 
              onClick={migrateServiceIds}
              disabled={isMigrating}
              className={`text-[10px] font-bold uppercase tracking-widest transition-all ${isMigrating ? 'text-gray-400 cursor-not-allowed' : 'text-orange-500 hover:text-orange-600 underline'}`}
            >
              {isMigrating ? 'Migrating...' : 'Fix Missing IDs'}
            </button>
          </div>
        </div>

        <div className="flex flex-col md:flex-row items-center gap-4 w-full xl:w-auto">
          {/* Layout Toggle */}
          <div className="flex bg-white border border-gray-200 rounded-lg p-1 shadow-sm mr-2">
            <button 
              onClick={() => setLayout('grid')}
              className={`p-1.5 rounded-md transition-all ${layout === 'grid' ? 'bg-orange-500 text-white shadow-sm' : 'text-gray-400 hover:text-gray-600'}`}
              title="Grid View"
            >
              <LayoutGrid size={18} />
            </button>
            <button 
              onClick={() => setLayout('list')}
              className={`p-1.5 rounded-md transition-all ${layout === 'list' ? 'bg-orange-500 text-white shadow-sm' : 'text-gray-400 hover:text-gray-600'}`}
              title="List View"
            >
              <List size={18} />
            </button>
          </div>

          <div className="relative w-full md:w-80">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
            <input
              type="text"
              placeholder="Search services..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full pl-10 pr-4 py-2 bg-white border border-gray-200 rounded-lg text-sm font-medium focus:outline-none focus:ring-2 focus:ring-orange-500/20 transition-all shadow-sm"
            />
          </div>

          <div className="flex items-center gap-2 w-full md:w-auto">
            <div className="relative w-full md:w-48">
              <Briefcase className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
              <select
                value={categoryFilter}
                onChange={(e) => setCategoryFilter(e.target.value)}
                className="w-full pl-10 pr-4 py-2 bg-white border border-gray-200 rounded-lg text-sm font-bold text-gray-700 focus:outline-none focus:ring-2 focus:ring-orange-500/20 transition-all appearance-none shadow-sm"
              >
                <option value="All">All Categories</option>
                {categories.map(cat => (
                  <option key={cat} value={cat}>{cat}</option>
                ))}
              </select>
            </div>

            <button
              onClick={exportToCSV}
              className="flex items-center gap-2 px-4 py-2 bg-orange-500 text-white rounded-lg text-sm font-bold hover:bg-orange-600 transition-all shadow-sm shadow-orange-100 whitespace-nowrap"
            >
              <Download size={18} />
              Export CSV
            </button>
            
            {(search || categoryFilter !== 'All') && (
              <button 
                onClick={() => { setSearch(''); setCategoryFilter('All'); }}
                className="p-2 text-gray-400 hover:text-orange-500 transition-colors"
                title="Reset Filters"
              >
                <RotateCcw size={18} />
              </button>
            )}
          </div>
        </div>
      </div>

      {filteredServices.length === 0 ? (
        <div className="py-20 bg-white rounded-xl border border-dashed border-gray-200 flex flex-col items-center justify-center text-gray-400">
          <Briefcase size={48} className="mb-4 opacity-20" />
          <p className="font-medium">No services found</p>
        </div>
      ) : layout === 'grid' ? (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-4">
          {filteredServices.map((s) => (
            <div key={s.id} className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden flex flex-col group hover:shadow-xl hover:shadow-orange-500/5 transition-all duration-300">
              {/* Header Image */}
              <div className="relative h-40 bg-gray-50 overflow-hidden">
                {s.servicePhotoUrl ? (
                  <img src={s.servicePhotoUrl} alt={s.title} className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500" />
                ) : (
                  <div className="w-full h-full flex items-center justify-center text-gray-200">
                    <Briefcase size={40} className="opacity-10" />
                  </div>
                )}
                <div className="absolute top-4 right-4 flex gap-2">
                  <button
                    onClick={() => toggleStatus(s.id, s.isActive ?? true)}
                    className={`p-2 rounded-md backdrop-blur-md transition-all shadow-lg ${(s.isActive ?? true)
                        ? 'bg-emerald-500/90 text-white'
                        : 'bg-orange-500/90 text-white'
                      }`}
                  >
                    {(s.isActive ?? true) ? <Check size={18} /> : <EyeOff size={18} />}
                  </button>
                </div>
              </div>

              {/* Content */}
              <div className="p-5 flex flex-col flex-1">
                <div className="flex justify-between items-start mb-4">
                  <div className="flex-1">
                    <span className={`text-[10px] font-bold uppercase tracking-widest px-2 py-0.5 rounded border inline-block mb-2 ${getCategoryColor(s.category)}`}>
                      {s.category} {s.subcategory && `> ${s.subcategory}`}
                    </span>
                    <h3 className="text-lg font-bold text-gray-900 line-clamp-1">{s.title || 'Untitled Service'}</h3>
                    <p className="text-xs text-gray-400 font-medium">By {s.providerName || 'Unknown Provider'}</p>
                  </div>
                  <div className="flex flex-col items-end gap-1">
                    <div className="flex items-center gap-1 text-amber-500 font-bold text-sm">
                      <Star size={14} fill="currentColor" />
                      {getServiceStats(s.id).avgRating}
                    </div>
                    <span className="text-[10px] text-gray-400 font-bold uppercase">{getServiceStats(s.id).reviewCount} Reviews</span>
                  </div>
                </div>

                <div className="flex items-center gap-4 mb-6">
                  <div className="flex items-center gap-1.5 text-gray-500 text-xs font-semibold">
                    <Calendar size={14} />
                    {getServiceStats(s.id).totalBookings} Bookings
                  </div>
                </div>

                <p className="text-sm text-gray-500 line-clamp-2 mb-6 flex-1 italic leading-relaxed">
                  {s.description || 'No description provided.'}
                </p>

                <div className="pt-4 border-t border-gray-50 flex items-center justify-between mt-auto">
                  <span className="text-lg font-bold text-gray-900">RM {Number(s.price).toLocaleString(undefined, { minimumFractionDigits: 2 })}</span>
                  <button
                    onClick={() => setSelectedService(s)}
                    className="px-4 py-2 bg-gray-900 text-white rounded-md text-xs font-bold hover:bg-orange-500 transition-colors flex items-center gap-2"
                  >
                    <Eye size={14} />
                    View Details
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden">
          <table className="w-full text-left">
            <thead>
              <tr className="bg-gray-50/50 border-b border-gray-100">
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest">Service</th>
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest">Provider</th>
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest">Category</th>
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest text-center">Bookings</th>
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest text-center">Rating</th>
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest">Price</th>
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest text-center">Status</th>
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {filteredServices.map((s) => {
                const stats = getServiceStats(s.id);
                const provider = users.find(u => u.id === s.providerId);
                return (
                  <tr key={s.id} className="hover:bg-gray-50/50 transition-colors">
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-4">
                        <div className="w-12 h-12 rounded-lg bg-gray-100 overflow-hidden shrink-0">
                          {s.servicePhotoUrl ? (
                            <img src={s.servicePhotoUrl} alt={s.title} className="w-full h-full object-cover" />
                          ) : (
                            <div className="w-full h-full flex items-center justify-center text-gray-300">
                              <Briefcase size={20} />
                            </div>
                          )}
                        </div>
                        <div className="min-w-0">
                          <p className="text-sm font-bold text-gray-900 truncate">{s.title || 'Untitled'}</p>
                          <p className="text-[10px] font-medium text-gray-400 line-clamp-1">{s.customId || s.id}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="min-w-0">
                        <p className="text-sm font-bold text-gray-900 truncate">{s.providerName || 'Unknown'}</p>
                        <p className="text-[10px] font-medium text-gray-400 truncate">{provider?.customId || s.providerId || 'No ID'}</p>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <span className={`px-2 py-1 rounded text-[10px] font-bold uppercase tracking-wider border ${getCategoryColor(s.category)}`}>
                        {s.category}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-center">
                      <div className="flex flex-col items-center gap-1">
                        <span className="text-sm font-bold text-gray-900">{stats.totalBookings}</span>
                        <span className="text-[10px] font-bold text-gray-400 uppercase tracking-tight">Bookings</span>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-center">
                      <div className="flex flex-col items-center gap-1">
                        <div className="flex items-center gap-1 text-sm font-bold text-gray-900">
                          <Star size={12} className="text-amber-500" fill="currentColor" />
                          {stats.avgRating}
                        </div>
                        <span className="text-[10px] font-bold text-gray-400 uppercase tracking-tight">{stats.reviewCount} Reviews</span>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <span className="text-sm font-bold text-gray-900">RM {Number(s.price).toLocaleString(undefined, { minimumFractionDigits: 2 })}</span>
                    </td>
                  <td className="px-6 py-4">
                    <div className="flex justify-center">
                      <span className={`px-2.5 py-1 rounded-full text-[10px] font-bold flex items-center gap-1.5 ${(s.isActive ?? true) ? 'bg-emerald-50 text-emerald-600' : 'bg-orange-50 text-orange-600'}`}>
                        <div className={`w-1.5 h-1.5 rounded-full ${(s.isActive ?? true) ? 'bg-emerald-500' : 'bg-orange-500'}`} />
                        {(s.isActive ?? true) ? 'Active' : 'Hidden'}
                      </span>
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <div className="flex items-center justify-end gap-2">
                      <button 
                        onClick={() => toggleStatus(s.id, s.isActive ?? true)}
                        className={`p-2 rounded-lg transition-colors ${(s.isActive ?? true) ? 'text-gray-400 hover:text-orange-500 hover:bg-orange-50' : 'text-orange-500 bg-orange-50 hover:bg-orange-100'}`}
                        title={(s.isActive ?? true) ? 'Hide Service' : 'Show Service'}
                      >
                        {(s.isActive ?? true) ? <EyeOff size={16} /> : <Eye size={16} />}
                      </button>
                      <button 
                        onClick={() => setSelectedService(s)}
                        className="p-2 text-gray-400 hover:text-gray-900 hover:bg-gray-100 rounded-lg transition-colors"
                        title="View Details"
                      >
                        <FileText size={16} />
                      </button>
                    </div>
                  </td>
                </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      {/* DETAIL MODAL */}
      {selectedService && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={() => setSelectedService(null)} />
          <div className="relative bg-white w-full max-w-4xl max-h-[90vh] rounded-2xl overflow-hidden shadow-2xl animate-in zoom-in-95 duration-300 overflow-y-auto">
            <button
              onClick={() => setSelectedService(null)}
              className="absolute top-6 right-6 z-10 p-2 bg-white/80 backdrop-blur-md rounded-full text-gray-900 hover:bg-gray-100 transition-all"
            >
              <X size={24} />
            </button>

            <div className="grid grid-cols-1 lg:grid-cols-2">
              <div className="h-64 lg:h-auto bg-gray-100">
                <img src={selectedService.servicePhotoUrl} alt={selectedService.title} className="w-full h-full object-cover" />
              </div>
              <div className="p-8 lg:p-12 space-y-8">
                <div>
                  <span className="text-sm font-bold text-orange-500 uppercase tracking-widest">{selectedService.category}</span>
                  <h2 className="text-4xl font-extrabold text-gray-900 mt-2">{selectedService.title}</h2>
                  <p className="text-gray-500 mt-2 font-medium">
                    Provided by <span className="text-gray-900 font-bold">{selectedService.providerName}</span>
                    <span className="text-[10px] text-gray-400 font-bold uppercase ml-2 px-1.5 py-0.5 bg-gray-100 rounded">
                      {users.find(u => u.id === selectedService.providerId)?.customId || selectedService.providerId}
                    </span>
                  </p>
                </div>

                <div className="text-3xl font-bold text-gray-900">RM {Number(selectedService.price).toLocaleString(undefined, { minimumFractionDigits: 2 })}</div>

                <div className="space-y-4">
                  <h4 className="font-bold text-gray-900 flex items-center gap-2">
                    <div className="w-1.5 h-5 bg-orange-500 rounded-full" />
                    About this service
                  </h4>
                  <p className="text-sm text-gray-600 leading-relaxed italic">"{selectedService.description}"</p>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
                  <div className="space-y-3">
                    <h4 className="text-xs font-bold text-gray-400 uppercase tracking-widest">Includes</h4>
                    <div className="space-y-2">
                      {(selectedService.details || []).map((item, i) => (
                        <div key={i} className="flex items-center gap-2 text-xs text-gray-600 font-medium">
                          <Check size={14} className="text-emerald-500" /> {item}
                        </div>
                      ))}
                    </div>
                  </div>
                  <div className="space-y-3">
                    <h4 className="text-xs font-bold text-gray-400 uppercase tracking-widest">Add-ons</h4>
                    <div className="space-y-2">
                      {(selectedService.addOns || []).map((addon, i) => (
                        <div key={i} className="flex items-center justify-between text-xs text-gray-600 font-medium p-2 bg-gray-50 rounded">
                          <span>{addon.name}</span>
                          <span className="font-bold text-orange-500">+RM{addon.price}</span>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>

                <div className="space-y-4">
                  <h4 className="text-xs font-bold text-gray-400 uppercase tracking-widest">Gallery</h4>
                  <div className="flex gap-2 overflow-x-auto pb-2 scrollbar-hide">
                    {(selectedService.galleryUrls || []).map((url, i) => (
                      <img key={i} src={url} className="h-20 w-20 rounded-md object-cover border border-gray-100 shrink-0 shadow-sm" />
                    ))}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function ReportsPage({ reports }: { reports: Report[] }) {
  const [loadingId, setLoadingId] = useState<string | null>(null);

  const handleResolve = async (id: string) => {
    setLoadingId(id);
    try {
      await updateDoc(doc(db, 'reports', id), { status: 'resolved' });
    } catch (e: any) {
      alert(`Failed to resolve: ${e.message}`);
    } finally {
      setLoadingId(null);
    }
  };

  const handleDelete = async (id: string) => {
    if (!window.confirm('Are you sure you want to delete this report?')) return;
    try {
      await updateDoc(doc(db, 'reports', id), { status: 'deleted' }); // or deleteDoc
      // Actually let's just delete it
      const { deleteDoc } = await import('firebase/firestore');
      await deleteDoc(doc(db, 'reports', id));
    } catch (e: any) {
      alert(`Failed to delete: ${e.message}`);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-lg font-bold text-gray-900 uppercase">Customer Reports</h1>
          <p className="text-gray-500 text-sm font-medium">Tracking and resolving platform issues ({reports.length})</p>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-4">
        {reports.length === 0 ? (
          <div className="py-20 bg-white rounded-xl border border-dashed border-gray-200 flex flex-col items-center justify-center text-gray-400">
            <Check size={48} className="mb-4 opacity-20" />
            <p className="font-medium">No pending reports</p>
            <p className="text-xs">Great job! All customer issues are cleared.</p>
          </div>
        ) : reports.map((rpt) => (
              <div key={rpt.id} className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden p-6">
                <div className="flex flex-col md:flex-row justify-between gap-8">
                  <div className="flex-1 space-y-5">
                    <div className="flex items-start justify-between">
                      <div className="flex items-center gap-4">
                        <div className="relative">
                          {rpt.customerProfileUrl ? (
                            <img src={rpt.customerProfileUrl} alt={rpt.customerName} className="w-12 h-12 rounded-full object-cover border-2 border-orange-100 shadow-sm" />
                          ) : (
                            <div className="w-12 h-12 bg-orange-100 text-orange-600 rounded-full flex items-center justify-center font-black text-lg">
                              {rpt.customerName?.[0]?.toUpperCase()}
                            </div>
                          )}
                          <div className="absolute -bottom-1 -right-1 w-5 h-5 bg-white rounded-full flex items-center justify-center shadow-sm">
                            <Users size={12} className="text-orange-500" />
                          </div>
                        </div>
                        <div>
                          <h3 className="font-black text-gray-900 leading-tight text-lg">{rpt.customerName}</h3>
                          <p className="text-[10px] text-gray-400 font-bold uppercase tracking-widest mt-0.5">ID: {rpt.customerCustomId || 'CU-PENDING'}</p>
                        </div>
                      </div>
                      <span className={`px-3 py-1.5 rounded-full text-[10px] font-black border uppercase tracking-widest ${
                        rpt.status === 'resolved' 
                        ? 'bg-emerald-50 text-emerald-600 border-emerald-100' 
                        : 'bg-amber-50 text-amber-600 border-amber-100 animate-pulse'
                      }`}>
                        {rpt.status}
                      </span>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <div className="p-3 bg-gray-50 rounded-lg border border-gray-100">
                        <p className="text-[9px] font-black text-gray-400 uppercase tracking-tighter mb-1">Booking Info</p>
                        <p className="text-sm font-black text-gray-800">{rpt.serviceName}</p>
                        <p className="text-[11px] font-bold text-orange-600 uppercase mt-0.5">Order ID: {rpt.orderId}</p>
                      </div>
                      <div className="p-3 bg-gray-50 rounded-lg border border-gray-100">
                        <p className="text-[9px] font-black text-gray-400 uppercase tracking-tighter mb-1">Assigned Provider</p>
                        <p className="text-sm font-black text-gray-800">{rpt.providerName}</p>
                        <p className="text-[11px] font-bold text-gray-500 uppercase mt-0.5">ID: {rpt.providerCustomId || 'PR-PENDING'}</p>
                      </div>
                    </div>

                    <div className="bg-gray-50/50 p-5 rounded-xl border border-gray-100 relative">
                      <div className="absolute top-4 right-4">
                        <FileText size={16} className="text-gray-200" />
                      </div>
                      <p className="text-[10px] font-black text-gray-400 uppercase tracking-widest mb-3">Report Details</p>
                      <p className="text-sm text-gray-700 leading-relaxed font-medium italic">"{rpt.issue}"</p>
                    </div>

                    <div className="flex items-center gap-6 text-[10px] font-bold text-gray-400 uppercase tracking-widest pt-2">
                      <div className="flex items-center gap-1.5">
                        <Clock size={14} className="text-gray-300" />
                        {rpt.timestamp?.seconds ? new Date(rpt.timestamp.seconds * 1000).toLocaleString() : 'Just now'}
                      </div>
                      <div className="flex items-center gap-1.5">
                        <Bookmark size={14} className="text-gray-300" />
                        Report ID: {rpt.id.substring(0, 8)}
                      </div>
                    </div>
                  </div>

                  <div className="flex md:flex-col justify-end gap-3 shrink-0 pt-2">
                {rpt.status !== 'resolved' && (
                  <button
                    onClick={() => handleResolve(rpt.id)}
                    disabled={loadingId === rpt.id}
                    className="px-6 py-2.5 bg-emerald-500 text-white rounded-lg font-bold text-xs shadow-lg shadow-emerald-100 hover:bg-emerald-600 transition-all flex items-center justify-center gap-2"
                  >
                    {loadingId === rpt.id ? (
                      <div className="animate-spin h-4 w-4 border-2 border-white border-t-transparent rounded-full" />
                    ) : (
                      <>
                        <Check size={16} />
                        Mark Resolved
                      </>
                    )}
                  </button>
                )}
                <button
                  onClick={() => handleDelete(rpt.id)}
                  className="px-6 py-2.5 bg-white border border-red-100 text-red-500 rounded-lg font-bold text-xs hover:bg-red-50 transition-all flex items-center justify-center gap-2"
                >
                  <Trash2 size={16} />
                  Delete
                </button>
              </div>
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
      <div className="w-full max-w-sm bg-white rounded-xl p-10 shadow-xl text-center">
        <div className="w-20 h-20 bg-orange-500 rounded-xl flex items-center justify-center mx-auto mb-8 shadow-lg shadow-orange-100">
          <ShieldCheck size={40} className="text-white" />
        </div>
        <h2 className="text-xl font-bold text-gray-900 mb-2">Welcome Back</h2>
        <p className="text-gray-500 text-sm mb-10">Login to access the admin console</p>

        {error && <div className="mb-6 p-3 bg-red-50 text-red-500 text-xs font-bold rounded-md border border-red-100">{error}</div>}

        <form onSubmit={handleLogin} className="space-y-6 text-left">
          <div className="space-y-2">
            <label className="text-[13px] font-medium text-gray-500 px-1">Email address</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full px-5 py-4 bg-gray-50 border-none rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500 font-medium text-base text-gray-900 transition-all placeholder:text-gray-300"
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
